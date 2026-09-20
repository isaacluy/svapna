module NotesImport
  # Turns one Apple Notes export into structured entries. Pure: no database, no
  # file system, no clock. Everything that writes lives in Committer.
  #
  #   NotesImport::Parser.new(text).call
  #   # => #<Result source="Sueños p.14", entries=[...], skipped=[...]>
  class Parser
    # A line of nothing but three or more dashes: hyphen, en dash, em dash or
    # horizontal bar. Apple Notes produces "———"; typing it by hand gives "---".
    DIVIDER = /\A[ \t]*[-‐-―−]{3,}[ \t]*\z/

    # YYYY/MM/DD, also tolerating - and . as separators.
    DATE = %r{\A[ \t]*(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})[ \t]*\z}

    Result = Struct.new(:source, :entries, :skipped, keyword_init: true) do
      def any? = entries.any?
    end

    ParsedEntry = Struct.new(
      :body, :written_on, :position, :language, :important, :digest,
      keyword_init: true
    )

    Skipped = Struct.new(:position, :reason, :preview, keyword_init: true)

    def initialize(text)
      @text = Text.normalize(text)
    end

    def call
      segments = split_on_dividers

      # Everything before the first divider is the note title. It labels the
      # whole file ("Sueños p.14"); it is never an entry title.
      source = segments.shift.to_s.strip.presence

      entries = []
      skipped = []

      segments.each_with_index do |segment, index|
        entry = parse_segment(segment, position: index)

        if entry.is_a?(ParsedEntry)
          entries << entry
        else
          skipped << entry
        end
      end

      if segments.empty?
        skipped << Skipped.new(
          position: 0,
          reason: "No divider line found, so there was nothing to split into entries",
          preview: preview(@text)
        )
      end

      Result.new(source: source, entries: entries, skipped: skipped)
    end

    private
      def split_on_dividers
        segments = [ [] ]

        @text.split("\n", -1).each do |line|
          if line.match?(DIVIDER)
            segments << []
          else
            segments.last << line
          end
        end

        segments.map { |lines| lines.join("\n") }
      end

      def parse_segment(segment, position:)
        lines = segment.split("\n", -1)
        date_index = lines.index { |line| line.strip.present? }

        if date_index.nil?
          return Skipped.new(position: position, reason: "Empty section", preview: "")
        end

        match = lines[date_index].match(DATE)

        if match.nil?
          return Skipped.new(
            position: position,
            reason: "Expected a date like 2026/09/18 but found #{lines[date_index].strip.truncate(40).inspect}",
            preview: preview(segment)
          )
        end

        written_on = safe_date(match)

        if written_on.nil?
          return Skipped.new(
            position: position,
            reason: "#{lines[date_index].strip} is not a real date",
            preview: preview(segment)
          )
        end

        body = clean_body(lines[(date_index + 1)..] || [])

        if body.blank?
          return Skipped.new(
            position: position,
            reason: "#{written_on} has a date but no body",
            preview: ""
          )
        end

        ParsedEntry.new(
          body: body,
          written_on: written_on,
          position: position,
          language: LanguageDetector.call(body),
          important: important?(body),
          digest: Entry.digest_for(body)
        )
      end

      def safe_date(match)
        Date.new(match[1].to_i, match[2].to_i, match[3].to_i)
      rescue Date::Error
        nil
      end

      # Keeps paragraph breaks, drops the ragged blank lines around them.
      def clean_body(lines)
        lines.join("\n").gsub(/[ \t]+$/, "").gsub(/\n{3,}/, "\n\n").strip
      end

      def important?(body)
        Importance.important?(body)
      end

      def preview(text)
        text.to_s.squish.truncate(120)
      end
  end
end
