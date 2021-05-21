def partition_volume(total_volume_size, partial_volume, partition_size) {
    def (x_partition_size, y_partition_size, z_partition_size) = size_components(partition_size)
    def (start_x, start_y, start_z, dx, dy, dz) = get_processed_volume(total_volume_size, partial_volume)
    def ncols = ((dx % x_partition_size) > 0 ? (dx / x_partition_size + 1) : (dx / x_partition_size)) as int
    def nrows =  ((dy % y_partition_size) > 0 ? (dy / y_partition_size + 1) : (dy / y_partition_size)) as int
    def nslices = ((dz % z_partition_size) > 0 ? (dz / z_partition_size + 1) : (dz / z_partition_size)) as int
    [0..ncols-1, 0..nrows-1, 0..nslices-1]
        .combinations()
        .collect {
            def start_col = it[0] * x_partition_size
            def end_col = start_col + x_partition_size
            if (end_col > dx) {
                end_col = dx
            }
            def start_row = it[1] * y_partition_size
            def end_row = start_row + y_partition_size
            if (end_row > dy) {
                end_row = dy
            }
            def start_slice = it[2] * z_partition_size
            def end_slice = start_slice + z_partition_size
            if (end_slice > dz) {
                end_slice = dz
            }
            [
                "${start_x + start_col},${start_y + start_row},${start_z + start_slice}",
                "${start_x + end_col},${start_y + end_row},${start_z + end_slice}"
            ]
        }
}

def number_of_subvols(total_volume_size, partial_volume, partition_size) {
    def (x_partition_size, y_partition_size, z_partition_size) = size_components(partition_size)
    def (start_x, start_y, start_z, dx, dy, dz) = get_processed_volume(total_volume_size, partial_volume)
    def ncols = ((dx % x_partition_size) > 0 ? (dx / x_partition_size + 1) : (dx / x_partition_size)) as int
    def nrows =  ((dy % y_partition_size) > 0 ? (dy / y_partition_size + 1) : (dy / y_partition_size)) as int
    def nslices = ((dz % z_partition_size) > 0 ? (dz / z_partition_size + 1) : (dz / z_partition_size)) as int
    return ncols * nrows * nslices
}

def size_components(sz) {
    def x_sz
    def y_sz
    def z_sz
    if (sz instanceof Number) {
        [ sz, sz, sz ]
    } else {
        sz
    }
}

// returns the adjusted partial volume as [<start> <dims>]
def get_processed_volume(total_volume_size, partial_volume) {
    def (width, height, depth) = total_volume_size
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
