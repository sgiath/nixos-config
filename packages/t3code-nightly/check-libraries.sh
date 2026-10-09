# Sourced by the t3code-nightly{,-desktop} install checks.

# assertResolved FILE...: fail when ldd cannot resolve a library of FILE.
assertResolved() {
	local file out failed=0
	for file in "$@"; do
		out="$(ldd "$file")"
		if grep 'not found' <<<"$out" >&2; then
			echo "ERROR: unresolved libraries in ${file}" >&2
			failed=1
		fi
	done
	return "$failed"
}

# assertLinked FILE SONAME...: fail unless FILE resolves each SONAME, i.e. it
# is loaded at startup and dlopen() by soname finds it.
assertLinked() {
	local file="$1" out soname failed=0
	shift
	out="$(ldd "$file")"
	for soname in "$@"; do
		if ! grep -q "^[[:space:]]*${soname} => /" <<<"$out"; then
			echo "ERROR: ${file} does not load ${soname}" >&2
			failed=1
		fi
	done
	return "$failed"
}

# assertHeadlessShellResolved ZIP: unpack the Chrome headless shell and check
# it and its bundled libraries against the current LD_LIBRARY_PATH.
assertHeadlessShellResolved() {
	local dir="${TMPDIR}/headless-shell"
	unzip -q "$1" -d "$dir"
	local files=("$dir"/*/chrome-headless-shell "$dir"/*/*.so*)
	assertResolved "${files[@]}"
}
