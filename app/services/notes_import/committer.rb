module NotesImport
  # The only part of the importer that writes. Takes a Parser::Result and
  # persists it as one Import plus its entries, in a single transaction.
  #
  # Idempotent: re-importing the same file creates nothing and reports the
  # entries as duplicates.
  class Committer
    def self.call(...) = new(...).call

    def initialize(result, filename: nil)
      @result = result
      @filename = filename
      @created = 0
      @duplicates = 0
      # Guards against the same entry appearing twice *within one file*, which
      # the database index alone would only catch as an exception.
      @seen = Set.new
    end

    def call
      Import.transaction do
        import = Import.create!(
          source: @result.source,
          filename: @filename,
          parse_errors: @result.skipped.map(&:to_h)
        )

        @result.entries.each { |parsed| persist(parsed, import) }

        import.update!(
          entries_count: @created,
          duplicate_count: @duplicates,
          skipped_count: @result.skipped.size
        )

        import
      end
    end

    private
      def persist(parsed, import)
        key = [ parsed.written_on, parsed.digest ]

        if @seen.include?(key) || duplicate?(parsed)
          @duplicates += 1
          return
        end

        @seen << key

        # Savepoint, so losing a race with the unique index costs this one entry
        # rather than aborting the whole transaction.
        entry = Entry.transaction(requires_new: true) do
          Entry.create!(
            body: parsed.body,
            written_on: parsed.written_on,
            position: parsed.position,
            language: parsed.language,
            status: :published,
            source: @result.source,
            import: import,
            # The entry's own date is the truth about when it was written, so
            # created_at follows it. Midday UTC keeps it on the right day in any
            # timezone the app is later viewed from.
            created_at: timestamp_for(parsed.written_on),
            updated_at: timestamp_for(parsed.written_on)
          )
        end

        entry.tag!(Import::IMPORTANT_TAG) if parsed.important
        @created += 1
      rescue ActiveRecord::RecordNotUnique
        @duplicates += 1
      end

      def duplicate?(parsed)
        Entry.imported.exists?(written_on: parsed.written_on, body_digest: parsed.digest)
      end

      def timestamp_for(date)
        Time.utc(date.year, date.month, date.day, 12)
      end
  end
end
