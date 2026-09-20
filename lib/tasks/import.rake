# Import Apple Notes exports from the command line.
#
#   bin/d r import:notes FILE=tmp/notes/suenos-p14.txt
#   bin/d r import:notes FILE='tmp/notes/*.txt'      # quote it: Ruby globs, not the shell
#   bin/d r import:undo IMPORT=3
#
# Put the files somewhere inside the repo so the container can see them;
# tmp/ is gitignored and works well.
namespace :import do
  desc "Import Apple Notes exports (FILE=path or glob)"
  task notes: :environment do
    pattern = ENV["FILE"].presence
    abort "FILE is required, e.g. bin/d r import:notes FILE='tmp/notes/*.txt'" if pattern.nil?

    paths = Dir.glob(pattern).select { |path| File.file?(path) }.sort
    abort "No files matched #{pattern.inspect}" if paths.empty?

    totals = Hash.new(0)

    paths.each do |path|
      import = NotesImport::Runner.import_file(path)

      totals[:created] += import.entries_count
      totals[:duplicates] += import.duplicate_count
      totals[:skipped] += import.skipped_count

      puts format("%-34s import #%-4d %3d created  %3d duplicate  %3d skipped  %s",
                  File.basename(path), import.id, import.entries_count,
                  import.duplicate_count, import.skipped_count, import.source.to_s)

      import.parse_errors.each { |problem| puts "    ! #{problem['reason']}" }
    end

    if paths.size > 1
      puts format("%-34s %14s %3d created  %3d duplicate  %3d skipped",
                  "#{paths.size} files", "", totals[:created], totals[:duplicates], totals[:skipped])
    end

    puts "Undo any of these with: bin/d r import:undo IMPORT=<id>"
  end

  desc "Undo an import, deleting the entries it created (IMPORT=id)"
  task undo: :environment do
    id = ENV["IMPORT"].presence
    abort "IMPORT is required, e.g. bin/d r import:undo IMPORT=3" if id.nil?

    import = Import.find(id)
    count = import.entries.count
    import.destroy!

    puts "Undid import ##{id}, deleting #{count} #{'entry'.pluralize(count)}"
  end

  desc "List imports"
  task list: :environment do
    if Import.none?
      puts "No imports yet."
    else
      Import.recent.each do |import|
        puts format("#%-4d %-20s %3d entries  %s",
                    import.id, import.source.to_s.truncate(20),
                    import.entries.count, import.created_at.to_fs(:short))
      end
    end
  end
end
