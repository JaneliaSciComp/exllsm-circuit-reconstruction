def channels_json_inputs(data_dir, channels, suffix) {
    channels_inputs(data_dir, channels, "${suffix}.json")
        .inject('') {
            arg, item -> "${arg} -i ${data_dir}/${item}${suffix}.json"
        }
}

def channels_inputs(data_dir, channels, suffix) {
    return channels.collect {
        "${data_dir}/${it}${suffix}"
    }
}

def read_config(cf) {
    jsonSlurper = new groovy.json.JsonSlurper()
    return jsonSlurper.parse(cf)
}
