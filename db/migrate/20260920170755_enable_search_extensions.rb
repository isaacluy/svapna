# The search infrastructure: extensions, accent-insensitive text search
# configurations, and the IMMUTABLE resolver that lets a generated column pick
# a stemmer per row.
#
# Adding a language later means one more CREATE TEXT SEARCH CONFIGURATION plus
# one more WHEN branch in svapna_regconfig -- and, because altering a config
# does NOT recompute existing generated columns, a rewrite of entries.search_vector
# followed by a REINDEX.
class EnableSearchExtensions < ActiveRecord::Migration[8.1]
  # (config name, base configuration, stemmer dictionary)
  CONFIGURATIONS = [
    %w[svapna_es spanish spanish_stem],
    %w[svapna_en english english_stem]
  ].freeze

  def up
    enable_extension "unaccent"
    enable_extension "pg_trgm"

    CONFIGURATIONS.each do |name, base, stemmer|
      # unaccent is a *filtering* dictionary: it strips accents and passes the
      # result to the stemmer, which is what makes "sueno" match "sueños".
      # Going through a dictionary rather than the unaccent() function matters --
      # the function is STABLE and cannot be used in an index or a generated column.
      execute <<~SQL
        CREATE TEXT SEARCH CONFIGURATION public.#{name} (COPY = pg_catalog.#{base});
        ALTER TEXT SEARCH CONFIGURATION public.#{name}
          ALTER MAPPING FOR hword, hword_part, word WITH unaccent, #{stemmer};
      SQL
    end

    # A generated column may only call IMMUTABLE functions, and casting a text
    # column to regconfig is STABLE (it is a catalog lookup), so
    # to_tsvector(language::regconfig, body) is rejected. Declaring immutability
    # over schema-qualified *literal* config names is the standard way around it:
    # search_path cannot change what these resolve to.
    #
    # Deliberately not STRICT -- an unknown or NULL language must fall through to
    # 'simple' rather than nulling out the entire vector.
    execute <<~SQL
      CREATE FUNCTION public.svapna_regconfig(lang text)
      RETURNS regconfig
      LANGUAGE sql
      IMMUTABLE
      PARALLEL SAFE
      AS $$
        SELECT CASE lang
          WHEN 'es' THEN 'public.svapna_es'::regconfig
          WHEN 'en' THEN 'public.svapna_en'::regconfig
          ELSE 'pg_catalog.simple'::regconfig
        END
      $$;
    SQL
  end

  def down
    execute "DROP FUNCTION IF EXISTS public.svapna_regconfig(text);"
    CONFIGURATIONS.each do |name, _base, _stemmer|
      execute "DROP TEXT SEARCH CONFIGURATION IF EXISTS public.#{name};"
    end
    disable_extension "pg_trgm"
    disable_extension "unaccent"
  end
end
