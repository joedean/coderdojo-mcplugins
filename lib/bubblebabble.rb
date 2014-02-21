require "digest/md5"

module BubbleBabble
  class << self
    def md5(value)
      encode Digest::MD5.digest(value)
    end

    # Direct port of the Ruby 2.1 implementation, since JRuby doesn't
    # have it yet.
    def encode(digest)
      seed = 1
      vowels = ["a", "e", "i", "o", "u", "y"]
      consonants = ["b", "c", "d", "f", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z", "x"]
      digest = digest.to_s.bytes.to_a
      digest_len = digest.length
      result = ""

      i = j = 0
      result[j] = "x";
      j += 1

      while true
        if i >= digest_len
          result[j] = vowels[seed % 6]
          j += 1
          result[j] = consonants[16]
          j += 1
          result[j] = vowels[seed / 6]
          j += 1
          break
        end

        byte1 = digest[i]
        i += 1
        result[j] = vowels[(((byte1 >> 6) & 3) + seed) % 6]
        j += 1
        result[j] = consonants[(byte1 >> 2) & 15]
        j += 1
        result[j] = vowels[((byte1 & 3) + (seed / 6)) % 6]
        j += 1

        if i >= digest_len
          break
        end

        byte2 = digest[i]
        i += 1
        result[j] = consonants[(byte2 >> 4) & 15]
        j += 1
        result[j] = "-"
        j += 1
        result[j] = consonants[byte2 & 15]
        j += 1

        seed = (seed * 5 + byte1 * 7 + byte2) % 36
      end

      result[j] = "x"
      result
    end
  end
end
