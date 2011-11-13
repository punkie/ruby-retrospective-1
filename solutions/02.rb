class Collection
  def split_and_strip(source, split_char)
    source.split(split_char).map(&:strip)
  end
  
  def initialize(songs_string, artist_tags)
    @line = songs_string.lines.map { |song| split_and_strip(song, '.') }    
    @line = @line.map do |name, artist, genres_string, tags_string|
      genre, subgenre = split_and_strip(genres_string, ',')
      tags = artist_tags.fetch(artist, [])
      tags += [genre, subgenre].compact.map(&:downcase)
      tags += split_and_strip(tags_string, ',') unless tags_string.nil?
        
      Song.new(name, artist, genre, subgenre, tags)
    end 
  end
  
  def find(criteria)
    @line.select { |song| song.matches?(criteria) }
  end
  
end

class Song
  attr_reader :name, :artist, :genre, :subgenre, :tags
  
  def initialize(name, artist, genre, subgenre, tags)
    @name, @artist, @tags = name, artist, tags
    @genre, @subgenre = genre, subgenre
  end
  
  def matches?(criteria)
    criteria.all? do |type, value|
      case type
        when :name then name == value
        when :artist then artist == value
        when :filter then value.(self)
        when :tags then check_tag_values(value)
      end
    end
  end
  
  def check_tag_values(tags)
    Array(tags).all? { |tag| matches_tag?(tag) }
  end
  
  def matches_tag?(tag)
    tag.end_with?("!") ^ tags.include?(tag.chomp "!")
  end

end
