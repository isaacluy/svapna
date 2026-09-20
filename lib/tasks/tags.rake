namespace :tags do
  desc "Delete tags that are no longer on any entry"
  task prune: :environment do
    orphans = Tag.where.not(id: Tagging.select(:tag_id))

    if orphans.none?
      puts "No unused tags."
    else
      names = orphans.pluck(:name)
      orphans.destroy_all
      puts "Removed #{names.size} unused #{'tag'.pluralize(names.size)}: #{names.sort.join(', ')}"
    end
  end
end
