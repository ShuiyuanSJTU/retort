# frozen_string_literal: true

desc "Replace emojis in retort table with their normalized versions and remove invalid emojis"
task "retort:resolve-alias", [] => [:environment] do |_, args|
  table_existing_emojis = Retort.unscoped.select(:emoji).distinct.pluck(:emoji)
  puts "#{table_existing_emojis.length} existing emojis found in retort table."
  non_existing_emojis = table_existing_emojis.reject { |e| Emoji[e].present? }
  puts "#{non_existing_emojis.length} emojis not found in discourse-emoji gem."
  alias_map = {}
  invalid_emojis = []
  non_existing_emojis.each do |emoji|
    normized_emoji = Retort.normalize_emoji(emoji)
    if !Emoji[normized_emoji].present?
      invalid_emojis << emoji
    else
      alias_map[emoji] = normized_emoji
    end
  end
  puts "Found #{alias_map.length} emojis that need to be updated."
  if invalid_emojis.any?
    puts "Found #{invalid_emojis.length} invalid emojis: #{invalid_emojis.join(', ')}"
    puts "Removing invalid emojis from retort table."
    Retort.unscoped.where(emoji: invalid_emojis).delete_all
  end
  puts "Updating emojis in retort table."
  alias_map.each do |old_emoji, new_emoji|
    puts "#{old_emoji} -> #{new_emoji}"
    begin
      Retort.unscoped.where(emoji: old_emoji).update_all(emoji: new_emoji)
    rescue ActiveRecord::RecordNotUnique
      Retort.transaction do
        Retort
          .unscoped
          .select("r1.*")
          .from(Retort.unscoped, :r1)
          .where("r1.emoji = ?", old_emoji)
          .where(
            "EXISTS (SELECT 1 FROM retorts AS r2
            WHERE r2.emoji = ?
            AND r1.user_id = r2.user_id
            AND r1.post_id = r2.post_id)",
            new_emoji,
          )
          .destroy_all
        Retort.unscoped.where(emoji: old_emoji).update_all(emoji: new_emoji)
      end
    end
  end
end
