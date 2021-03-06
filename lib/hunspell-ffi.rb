# encoding: utf-8
require 'ffi'
class Hunspell  
  module C
    extend FFI::Library
    ffi_lib %w[
      libhunspell-1.3
      libhunspell-1.3.so.0
      libhunspell-1.2
      libhunspell-1.2.so.0
      libhunspell
    ]
    attach_function :Hunspell_create, [:string, :string], :pointer
    attach_function :Hunspell_spell, [:pointer, :string], :bool
    attach_function :Hunspell_suggest, [:pointer, :pointer, :string], :int
    attach_function :Hunspell_add, [:pointer, :string], :int
    attach_function :Hunspell_add_with_affix, [:pointer, :string, :string], :int
    attach_function :Hunspell_analyze, [:pointer, :pointer, :string], :int
    attach_function :Hunspell_free_list, [:pointer, :pointer, :int], :void
    attach_function :Hunspell_get_dic_encoding, [:pointer], :string
    attach_function :Hunspell_remove, [:pointer, :string], :int    
    attach_function :Hunspell_stem, [:pointer, :pointer, :string], :int
  end

  ##
  # The affix file used to check words

  attr_reader :affix

  ##
  # The dictionary file used to check words

  attr_reader :dictionary

  ##
  # Creates a spell-checking instance.  If only +path+ is given, Hunspell will
  # look for a dictionary using the language of your current locale, checking
  # LC_ALL, LC_MESSAGES and LANG.  If you would like to spell check words of a
  # specific language provide it as the second parameter, +language+.
  #
  # You may also directly provide the affix file as the +path+ argument and
  # the dictionary file as the +language+ argument, provided they both exist.
  # This is for legacy use of Hunspell.

  def initialize(path, language = nil)
    if File.exist?(path) and language and File.exist?(language) then
      @affix      = path
      @dictionary = language
    else
      language ||= find_language

      @affix      = File.join path, "#{language}.aff"
      @dictionary = File.join path, "#{language}.dic"
    end

    raise ArgumentError,
          "Hunspell could not find affix file #{@affix}" unless
      File.exist?(@affix)
    raise ArgumentError,
          "Hunspell could not find dictionary file #{@dictionary}" unless
      File.exist?(@dictionary)

    @handler = C.Hunspell_create @affix, @dictionary
    @dic_encoding = nil

    if Object.const_defined? :Encoding then
      begin
        encoding_name = C.Hunspell_get_dic_encoding @handler
        @dic_encoding = Encoding.find encoding_name
      rescue ArgumentError
        # unknown encoding name, results will be ASCII-8BIT
      end
    end
  end

  def find_language
    %w[LC_ALL LC_MESSAGES LANG].each do |var|
      next unless value = ENV[var]

      lang, charset = value.split('.', 2)

      return lang if charset
    end

    nil
  end

  # Returns true for a known word or false.
  def spell(word)
    C.Hunspell_spell(@handler, word)
  end
  alias_method :check, :spell
  alias_method :check?, :check  
  
  # Returns an array with suggested words or returns and empty array.
  def suggest(word)
    list_pointer = FFI::MemoryPointer.new(:pointer, 1)

    len = C.Hunspell_suggest(@handler, list_pointer, word)

    read_list(list_pointer, len)
  end
  
  # Add word to the run-time dictionary
  def add(word)
    C.Hunspell_add(@handler, word)
  end
  
  # Add word to the run-time dictionary with affix flags of
  # the example (a dictionary word): Hunspell will recognize
  # affixed forms of the new word, too.
  def add_with_affix(word, example)
    C.Hunspell_add_with_affix(@handler, word, example)
  end

  # Performs morphological analysis of +word+.  See hunspell(4) for details on
  # the output format.
  def analyze(word)
    list_pointer = FFI::MemoryPointer.new(:pointer, 1)

    len = C.Hunspell_analyze(@handler, list_pointer, word)

    read_list(list_pointer, len)
  end

  def read_list(list_pointer, len)
    return [] if len.zero?

    list = list_pointer.read_pointer

    strings = list.get_array_of_string(0, len)

    C.Hunspell_free_list(@handler, list_pointer, len)

    if @dic_encoding then
      strings.map do |string|
        string.force_encoding @dic_encoding
      end
    end

    strings
  end

  # Remove word from the run-time dictionary
  def remove(word)
    C.Hunspell_remove(@handler, word)
  end

  # Returns the stems of +word+
  def stem(word)
    list_pointer = FFI::MemoryPointer.new(:pointer, 1)

    len = C.Hunspell_stem(@handler, list_pointer, word)

    read_list(list_pointer, len)
  end

end
