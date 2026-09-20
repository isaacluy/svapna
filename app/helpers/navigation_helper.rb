module NavigationHelper
  # A nav link that marks itself current, for styling and for screen readers.
  # Prefix matching so /entries/9 still highlights "Entries"; "/" is matched
  # exactly, since every path starts with it.
  def nav_link_to(name, path)
    current = path == "/" ? request.path == "/" : request.path.start_with?(path)

    link_to name, path,
            class: "rounded-md px-2.5 py-2 #{current ? 'text-ink font-medium' : 'text-ink-faint hover:text-ink'}",
            aria: { current: ("page" if current) }
  end
end
