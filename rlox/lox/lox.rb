require "readline"
require "singleton"

require_relative "./scanner"
require_relative "./token"
require_relative "./parser"
require_relative "./ast_printer"
require_relative "./interpreter"

class LoxSingleton
  include Singleton
  attr_accessor :had_error

  def initialize()
    @had_error = false
    @had_runtime_error = false

    @scanner = Scanner.new()
    @parser = Parser.new()
    @ast_printer = AstPrinter.new()
    @interpreter = Interpreter.new()
  end

  def main(args)
    if args.length > 1
      puts("Usage: rlox [script]")
      exit(64)
    elsif args.length == 1
      run_file(args[0])
    else
      run_prompt()
    end
  end

  def run_file(path)
    run(File.read(path))
    exit(65) if @had_error
    exit(70) if @had_runtime_error
  end

  def run_prompt()
    while line = Readline.readline("> ", true)
      run(line)
      @had_error = false
      @had_runtime_error = false
    end
  end

  def run(source)
    tokens = @scanner.scan_tokens(source)
    expression = @parser.parse(tokens)

    return if @had_error # stop if there was a syntax error

    puts(@ast_printer.print(expression))
    puts(@interpreter.interpret(expression))
  end

  def error(source, message)
    case
    when source.is_a?(Numeric)
      report(source, "", message)
    when source.is_a?(Token) && source.type?(:EOF)
      report(source.line_num, " at end", message)
    when source.is_a?(Token)
      report(source.line_num, " at '#{source.lexeme}'", message)
    else
      puts("Error reporting error, source #{source} unknown")
    end
  end

  def runtime_error(token, message)
    STDERR.puts("#{message}\n[line #{token.line_num}]")
    @had_runtime_error = true
    return nil
  end

  private

  def report(line_num, where, message)
    puts("[line #{line_num}] Error#{where}: #{message}")
    @had_error = true
    return nil
  end
end

Lox = LoxSingleton.instance
