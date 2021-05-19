def partition_volume(volume) {
    partition_size = params.volume_partition_size
    def (start_x, start_y, start_z, dx, dy, dz) = get_processed_volume(volume, params.partial_volume)
    def ncols = ((dx % partition_size) > 0 ? (dx / partition_size + 1) : (dx / partition_size)) as int
    def nrows =  ((dy % partition_size) > 0 ? (dy / partition_size + 1) : (dy / partition_size)) as int
    def nslices = ((dz % partition_size) > 0 ? (dz / partition_size + 1) : (dz / partition_size)) as int
    [0..ncols-1, 0..nrows-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_col = it[0] * partition_size
            def end_col = start_col + partition_size
            if (end_col > dx) {
                end_col = dx
            }
            def start_row = it[1] * partition_size
            def end_row = start_row + partition_size
            if (end_row > dy) {
                end_row = dy
            }
            def start_slice = it[2] * partition_size
            def end_slice = start_slice + partition_size
            if (end_slice > dz) {
                end_slice = dz
            }
            [
                "${start_x + start_col},${start_y + start_row},${start_z + start_slice}",
                "${start_x + end_col},${start_y + end_row},${start_z + end_slice}"
            ]
        }
}

def get_processed_volume(volume, partial_volume) {
    def (width, height, depth) = volume
    if (partial_volume) {
        def (start_x, start_y, start_z, dx, dy, dz) = partial_volume.split(',').collect { it as int }
        if (start_x < 0 || start_x >= width) {
            log.error "Invalid start x: ${start_x}"
            throw new IllegalArgumentException("Invalid start x: ${start_x}")
        }
        if (start_y < 0 || start_y >= height) {
            log.error "Invalid start y: ${start_y}"
            throw new IllegalArgumentException("Invalid start y: ${start_y}")
        }
        if (start_z < 0 || start_z >= depth) {
            log.error "Invalid start z: ${start_z}"
            throw new IllegalArgumentException("Invalid start z: ${start_z}")
        }
        if (start_x + dx > width) dx = width - start_x
        if (start_y + dy > height) dy = height - start_y
        if (start_z + dz > depth) dz = depth - start_z
        [ start_x, start_y, start_z, dx, dy, dz]
    } else {
        [ 0, 0, 0, width, height, depth]
    }
}
