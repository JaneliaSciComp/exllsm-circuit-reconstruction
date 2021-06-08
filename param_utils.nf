include {
    global_em_params;
} from './params/global_params'

include {
    neuron_params;
} from './params/neuron_params'

include {
    stitching_params;
} from './params/stitching_params'

include {
    synapse_params;
} from './params/synapse_params'

include {
    vvd_params;
} from './params/vvd_params'

def default_em_params(Map ps) {
    global_em_params() +
    neuron_params() +
    stitching_params() +
    synapse_params() +
    vvd_params() +
    ps
}

def get_value_or_default(Map ps, String param, Object default_value) {
    if (ps[param])
        ps[param]
    else
        default_value
}

def get_list_or_default(Map ps, String param, List default_list) {
    def value
    if (ps[param])
        value = ps[param]
    else
        value = null
    return value instanceof String && value
        ? value.tokenize(',').collect { it.trim() }
        : default_list
}

def stitching_container_param(Map ps) {
    def stitching_container = ps.stitching_container
    if (!stitching_container)
        "${ps.exm_repo}/stitching:1.9.0"
    else
        stitching_container
}

def deconvolution_container_param(Map ps) {
    def deconvolution_container = ps.deconvolution_container
    if (!deconvolution_container)
        "${ps.deconv_repo}/matlab-deconv:1.0"
    else
        deconvolution_container
}

def exm_synapse_container_param(Map ps) {
    def exm_synapse_container = ps.exm_synapse_container
    if (!exm_synapse_container)
        "${ps.exm_repo}/synapse:1.3.0"
    else
        exm_synapse_container
}

def exm_synapse_dask_container_param(Map ps) {
    def exm_synapse_dask_container = ps.exm_synapse_dask_container
    if (!exm_synapse_dask_container)
        "${ps.exm_repo}/synapse-dask:1.3.1"
    else
        exm_synapse_dask_container
}

def exm_neuron_segmentation_container(Map ps) {
    def exm_neuron_segmentation_container = ps.exm_neuron_segmentation_container
    if (!exm_neuron_segmentation_container)
        "${ps.exm_repo}/neuron-segmentation:1.0.0"
    else
        exm_neuron_segmentation_container
}
