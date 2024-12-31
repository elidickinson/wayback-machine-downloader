# frozen_string_literal: true

module TidyBytes
  # Using a frozen array so we have a O(1) lookup time
  CP1252_MAP = Array.new(160) do |i|
    case i
    when 128 then [226, 130, 172]
    when 130 then [226, 128, 154]
    when 131 then [198, 146]
    when 132 then [226, 128, 158]
    when 133 then [226, 128, 166]
    when 134 then [226, 128, 160]
    when 135 then [226, 128, 161]
    when 136 then [203, 134]
    when 137 then [226, 128, 176]
    when 138 then [197, 160]
    when 139 then [226, 128, 185]
    when 140 then [197, 146]
    when 142 then [197, 189]
    when 145 then [226, 128, 152]
    when 146 then [226, 128, 153]
    when 147 then [226, 128, 156]
    when 148 then [226, 128, 157]
    when 149 then [226, 128, 162]
    when 150 then [226, 128, 147]
    when 151 then [226, 128, 148]
    when 152 then [203, 156]
    when 153 then [226, 132, 162]
    when 154 then [197, 161]
    when 155 then [226, 128, 186]
    when 156 then [197, 147]
    when 158 then [197, 190]
    when 159 then [197, 184]
    end
  end.freeze

  def self.included(base)
    base.class_eval do
      private

      def tidy_byte(byte)
        if byte < 160
          CP1252_MAP[byte]
        else
          byte < 192 ? [194, byte] : [195, byte - 64]
        end
      end

      public

    # Attempt to replace invalid UTF-8 bytes with valid ones. This method
    # naively assumes if you have invalid UTF8 bytes, they are either Windows
    # CP-1252 or ISO8859-1. In practice this isn't a bad assumption, but may not
    # always work.
    #
    # Passing +true+ will forcibly tidy all bytes, assuming that the string's
    # encoding is CP-1252 or ISO-8859-1.

      def tidy_bytes(force = false)
        return nil if empty?
        
        if force
          buffer = String.new(capacity: bytesize)
          each_byte do |b|
            cleaned = tidy_byte(b)
            buffer << cleaned.pack("C*") if cleaned
          end
          return buffer.force_encoding(Encoding::UTF_8)
        end

        buffer = String.new(capacity: bytesize)
        bytes = each_byte.to_a
        conts_expected = 0
        last_lead = 0

        bytes.each_with_index do |byte, i|
          if byte < 128 # ASCII
            buffer << byte
            next
          end

          if byte > 244 || byte > 240 # invalid bytes
            cleaned = tidy_byte(byte)
            buffer << cleaned.pack("C*") if cleaned
            next
          end

          is_cont = byte > 127 && byte < 192
          is_lead = byte > 191 && byte < 245

          if is_cont
            # Not expecting continuation byte? Clean up. Otherwise, now expect one less.
            if conts_expected == 0
              cleaned = tidy_byte(byte)
              buffer << cleaned.pack("C*") if cleaned
            else
              buffer << byte
              conts_expected -= 1
            end
          else
            if conts_expected > 0
              # Expected continuation, but got ASCII or leading? Clean backwards up to
              # the leading byte.
              (1..(i - last_lead)).each do |j|
                back_byte = bytes[i - j]
                cleaned = tidy_byte(back_byte)
                buffer << cleaned.pack("C*") if cleaned
              end
              conts_expected = 0
            end

            if is_lead
              # Final byte is leading? Clean it.
              if i == bytes.length - 1
                cleaned = tidy_byte(byte)
                buffer << cleaned.pack("C*") if cleaned
              else
                # Valid leading byte? Expect continuations determined by position of
                # first zero bit, with max of 3.
                buffer << byte
                conts_expected = byte < 224 ? 1 : byte < 240 ? 2 : 3
                last_lead = i
              end
            end
          end
        end

        buffer.force_encoding(Encoding::UTF_8)
      rescue
        nil
      end

      # Tidy bytes in place.
      def tidy_bytes!(force = false)
        result = tidy_bytes(force)
        result ? replace(result) : self
      end
    end
  end
end

class String
  include TidyBytes
end