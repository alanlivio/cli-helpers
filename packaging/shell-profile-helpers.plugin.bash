if [ -n "${BASH_SOURCE[0]:-}" ]; then
    _sph_plugin_src="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
    eval '_sph_plugin_src="${(%):-%x}"'
else
    _sph_plugin_src="$0"
fi

_sph_plugin_dir="$(cd -- "$(dirname -- "$_sph_plugin_src")/.." >/dev/null 2>&1 && pwd -P)"
[ -r "$_sph_plugin_dir/init.sh" ] && . "$_sph_plugin_dir/init.sh"
unset _sph_plugin_src _sph_plugin_dir
