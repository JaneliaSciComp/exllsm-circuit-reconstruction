def entries_inputs_args(data_dir, entries, flag, suffix, ext) {
    entries_inputs(data_dir, entries, "${suffix}${ext}")
        .inject('') {
            arg, item -> "${arg} ${flag} ${item}"
        }
}

def entries_inputs(data_dir, entries, suffix) {
    return entries.collect {
        if (data_dir != null && data_dir != '')
            "${data_dir}/${it}${suffix}"
        else
            "${it}${suffix}"
    }
}
