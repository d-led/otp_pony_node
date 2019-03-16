primitive Strings
    fun null_trimmed(buffer: Array[U8] val): String val^ =>
        try
            // try trimming the extra null terminators
            let trimmed: Array[U8] val = recover buffer.slice(0, buffer.find(0)?) end
            String.from_array(trimmed)
        else
            String.from_array(buffer)
        end