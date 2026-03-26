# frozen_string_literal: true

desc "Replace emojis in retort table with their normalized versions and remove invalid emojis"
task "retort:resolve-alias", [] => [:environment] do
  table_existing_emojis = Retort.unscoped.select(:emoji).distinct.pluck(:emoji)
  puts "#{table_existing_emojis.length} existing emojis found in retort table."
  non_existing_emojis = table_existing_emojis.reject { |e| Emoji[e].present? }
  puts "#{non_existing_emojis.length} emojis not found in discourse-emoji gem."
  alias_map = {}
  invalid_emojis = []
  non_existing_emojis.each do |emoji|
    normalized_emoji = Retort.normalize_emoji(emoji)
    if !Emoji[normalized_emoji].present?
      invalid_emojis << emoji
    else
      alias_map[emoji] = normalized_emoji
    end
  end
  puts "Found #{alias_map.length} emojis that need to be updated."
  if invalid_emojis.any?
    puts "Found #{invalid_emojis.length} invalid emojis: #{invalid_emojis.join(", ")}"
    puts "Removing invalid emojis from retort table."
    Retort.unscoped.where(emoji: invalid_emojis).delete_all
  end
  puts "Updating emojis in retort table."
  alias_map.each do |old_emoji, new_emoji|
    puts "#{old_emoji} -> #{new_emoji}"
    Retort.transaction do
      conflicting_retorts =
        Retort
          .unscoped
          .from("retorts AS old_retorts")
          .where("old_retorts.emoji = ?", old_emoji)
          .where(<<~SQL, new_emoji)
              EXISTS (
                SELECT 1
                FROM retorts AS new_retorts
                WHERE new_retorts.emoji = ?
                  AND new_retorts.user_id = old_retorts.user_id
                  AND new_retorts.post_id = old_retorts.post_id
              )
            SQL

      # Remove rows that would violate the unique index after normalization.
      Retort.unscoped.where(id: conflicting_retorts.select("old_retorts.id")).delete_all
      Retort.unscoped.where(emoji: old_emoji).update_all(emoji: new_emoji)
    end
  end
end
