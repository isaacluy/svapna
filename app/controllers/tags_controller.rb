class TagsController < ApplicationController
  def index
    @tags = Tag.in_use
               .left_joins(:taggings)
               .group(:id)
               .select("tags.*, count(taggings.id) AS entries_count")
               .order(Arel.sql("count(taggings.id) DESC, tags.name"))

    @unused = Tag.where.not(id: Tagging.select(:tag_id)).alphabetical
  end
end
