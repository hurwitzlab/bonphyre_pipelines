#!/usr/bin/env bash
#
# build.sh -- isolate exactly the files one workflow needs to run.
#
# Walks the include{}/includeConfig dependency graph starting from
# workflows/<workflow_name>/<workflow_name>.nf and its .config, follows every
# subworkflow, local module, and shared nextflow_modules tool module it
# actually references (plus any bin/ script those files call by name), and
# copies just that closure into <output_dir> -- preserving the same relative
# layout this repo already uses (nextflow_modules/ sitting beside
# viral_inference_benchmark/) so every include path resolves in the copy
# completely unmodified. Nothing is copied by directory-globbing; if a file
# isn't reachable from the workflow via include/includeConfig or referenced
# by name in a shell block, it isn't included.
#
# Assumes the standard repo layout: nextflow_modules cloned as a sibling of
# viral_inference_benchmark (see nextflow_pipeline/README.md "Prerequisites").
#
# Usage:
#   build.sh <workflow_name> <output_dir>
#
# Example:
#   ./build.sh i_mg_viralinference /tmp/i_mg_viralinference_build
#
# <output_dir> must not already exist. After copying, the script runs
# `nextflow run` on the copy once as a smoke test (from a scratch directory,
# so its own run litter never lands inside the isolated copy) -- its output
# lands in <output_dir>/build_validation.log. Nextflow prints the same
# generic "Script compilation failed" banner both for an unresolved/missing
# include path and for an unrelated script-structure error, so the banner
# alone doesn't tell you which -- read the specific message under it. A
# missing --reads glob or database path failing further in is a separate,
# expected concern (this workflow needs real runtime inputs this machine/copy
# doesn't have), not a build problem.

set -eo pipefail   # deliberately not -u: this targets stock macOS /bin/bash
                    # (3.2), where empty-array expansion under `set -u` is
                    # unreliable.

usage() {
    grep '^#' "$0" | sed -e '1d' -e 's/^# \{0,1\}//'
}

if [[ $# -ne 2 || "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 1
fi

workflow_name="$1"
output_dir="$2"

# Resolve repo layout relative to this script's own location, not the
# caller's cwd.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"    # .../viral_inference_benchmark/nextflow_pipeline
repo_root="$(cd "${script_dir}/.." && pwd)"                   # .../viral_inference_benchmark
repo_name="$(basename "${repo_root}")"

if ! modules_root="$(cd "${repo_root}/../nextflow_modules" 2>/dev/null && pwd)"; then
    echo "ERROR: nextflow_modules not found as a sibling of ${repo_root}." >&2
    echo "This repo's pipelines require nextflow_modules cloned next to it -- see nextflow_pipeline/README.md 'Prerequisites'." >&2
    exit 1
fi

workflow_nf="${script_dir}/workflows/${workflow_name}/${workflow_name}.nf"
workflow_config="${script_dir}/workflows/${workflow_name}/${workflow_name}.config"

if [[ ! -f "${workflow_nf}" ]]; then
    echo "ERROR: no workflow file at ${workflow_nf}" >&2
    exit 1
fi
if [[ ! -f "${workflow_config}" ]]; then
    echo "ERROR: no config file at ${workflow_config}" >&2
    exit 1
fi
if [[ -e "${output_dir}" ]]; then
    echo "ERROR: ${output_dir} already exists -- refusing to overwrite. Pick an empty/nonexistent path." >&2
    exit 1
fi

echo "[build] workflow:         ${workflow_name}"
echo "[build] repo root:        ${repo_root}"
echo "[build] nextflow_modules: ${modules_root}"
echo "[build] output:           ${output_dir}"

mkdir -p "${output_dir}"
manifest_file="${output_dir}/build_manifest.txt"
: > "${manifest_file}"

is_visited() { grep -qxF "$1" "${manifest_file}"; }
mark_visited() { echo "$1" >> "${manifest_file}"; }

# ---- Walk the include{}/includeConfig dependency graph ---------------------
# Both `include { A, B as C } from '<path>'` and `includeConfig '<path>'` are
# single-line, single- or double-quoted relative-path references in this
# codebase, so one pattern covers both: match the keyword-prefixed statement,
# then pull out just the trailing quoted path.

queue=("${workflow_nf}" "${workflow_config}")

while [[ ${#queue[@]} -gt 0 ]]; do
    current="${queue[0]}"
    queue=("${queue[@]:1}")

    current="$(cd "$(dirname "${current}")" && pwd)/$(basename "${current}")"

    if is_visited "${current}"; then
        continue
    fi
    if [[ ! -f "${current}" ]]; then
        echo "ERROR: dependency not found: ${current}" >&2
        exit 1
    fi
    mark_visited "${current}"

    current_dir="$(dirname "${current}")"

    while IFS= read -r rel_path; do
        [[ -z "${rel_path}" ]] && continue
        resolved="$(cd "${current_dir}" && cd "$(dirname "${rel_path}")" && pwd)/$(basename "${rel_path}")"
        queue+=("${resolved}")
    done < <(grep -oE "(include[[:space:]]*\{[^}]*\}[[:space:]]*from|includeConfig)[[:space:]]*['\"][^'\"]+['\"]" "${current}" \
                | grep -oE "['\"][^'\"]+['\"]\$" \
                | tr -d "\"'")
done

files=()
while IFS= read -r line; do
    files+=("${line}")
done < "${manifest_file}"

echo "[build] discovered ${#files[@]} include-graph files"

# ---- Pull in any bin/ script those files reference by name -----------------
# Nextflow doesn't express this as an include -- a process's shell block just
# calls the script by its bare filename -- so this is a name-match, not a
# graph walk.

bin_dir="${script_dir}/bin"
if [[ -d "${bin_dir}" ]]; then
    for script in "${bin_dir}"/*; do
        [[ -f "${script}" ]] || continue
        name="$(basename "${script}")"
        if grep -ql -- "${name}" "${files[@]}"; then
            mark_visited "${script}"
            files+=("${script}")
            echo "[build]   + referenced bin script: ${name}"
        fi
    done
fi

# ---- Copy, preserving relative layout ---------------------------------------

for f in "${files[@]}"; do
    if [[ "${f}" == "${modules_root}"/* ]]; then
        rel="${f#${modules_root}/}"
        dest="${output_dir}/nextflow_modules/${rel}"
    elif [[ "${f}" == "${repo_root}"/* ]]; then
        rel="${f#${repo_root}/}"
        dest="${output_dir}/${repo_name}/${rel}"
    else
        echo "ERROR: ${f} is outside both ${repo_root} and ${modules_root} -- don't know where to place it." >&2
        exit 1
    fi
    mkdir -p "$(dirname "${dest}")"
    cp "${f}" "${dest}"
done

echo "[build] copied ${#files[@]} files into ${output_dir}"

# ---- Validate: does the copy actually resolve on its own? ------------------

copied_workflow_nf="${output_dir}/${repo_name}/nextflow_pipeline/workflows/${workflow_name}/${workflow_name}.nf"
copied_workflow_config="${output_dir}/${repo_name}/nextflow_pipeline/workflows/${workflow_name}/${workflow_name}.config"
validation_log="${output_dir}/build_validation.log"

# Run from a scratch directory, not inside the deliverable copy itself --
# otherwise Nextflow's own run litter (.nextflow/, .nextflow.log, whatever
# params.outdir resolves to for trace/report/timeline) ends up inside the
# isolated copy, which defeats the point of an isolated copy.
scratch_dir="$(mktemp -d)"
echo "[build] validating isolated copy (scratch run dir: ${scratch_dir}): nextflow run ${copied_workflow_nf} -c ${copied_workflow_config}"
if ( cd "${scratch_dir}" && nextflow run "${copied_workflow_nf}" -c "${copied_workflow_config}" ) > "${validation_log}" 2>&1; then
    echo "[build] validation run exited 0 -- see ${validation_log}"
else
    echo "[build] validation run exited non-zero -- see ${validation_log}"
    echo "[build] read the specific error message in that log, not just the banner: Nextflow prints the same generic 'Script compilation failed' banner both for an unresolved/missing include path and for an unrelated script-structure error, so the banner alone doesn't mean a dependency is missing from this build -- check what it's actually pointing at."
fi
rm -rf "${scratch_dir}"

echo "[build] done: ${output_dir}"
echo "[build] file list: ${manifest_file}"
