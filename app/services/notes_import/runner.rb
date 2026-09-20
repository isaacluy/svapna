module NotesImport
  # Parse-then-commit, the entry point shared by the rake task and the UI.
  module Runner
    module_function

    def import(text, filename: nil)
      Committer.call(Parser.new(text).call, filename: filename)
    end

    def import_file(path)
      import(File.read(path), filename: File.basename(path))
    end
  end
end
