require 'gosu'
require 'set'

class Buttons
  def initialize
    @held = Set.new
    @pressed = Set.new
    @released = Set.new
  end

  def press(name)
    @pressed.add(name)
    @held.add(name)
  end

  def release(name)
    @released.add(name)
    @held.delete(name)
  end

  def held?(name)
    @held.include? name
  end

  def pressed?(name)
    @pressed.include? name
  end

  def released?(name)
    @released.include? name
  end

  def reset
    framereset
    @held.clear
  end

  def framereset
    @pressed.clear
    @released.clear
  end
end

class Animation
  def initialize(name, tile_size = 100)
    images = Gosu::Image.load_tiles(Gosu::Image.new(name), tile_size, tile_size)
    @graphics = Array.new(images.size)
    images.each_with_index do |image, i|
      @graphics[i] = Gosu::Image.new(image)
    end
  end
  def draw(frame, x, y, z)
    @graphics[frame].draw(x, y, z)
  end

  def size
    @graphics.size
  end
end

class Bullet
  attr_accessor :x
  attr_accessor :y

  def initialize(graphic, x, y)
    @graphic = graphic
    @x = x
    @y = y
  end

  def update
    @x += 5
    return @x > 280
  end

  def draw
    @graphic.draw(@x, @y, 100)
  end
end

class Spider
  attr_accessor :x
  attr_accessor :y
  attr_reader :color


  def initialize(color, x, y, speed)
    @spider = Gosu::Image.new('game/' + color + 'spider.png')
    @color = color
    @x = x
    @y = y
    @speed = speed
    @speed_frame = 0
    @hp = 5
  end

  def update
    @speed_frame = (@speed_frame + 1) % @speed
    if @speed_frame / (@speed - 1) == 1
      @x -= 2
    end
  end

  def draw
    @spider.draw(@x, @y, 10)
  end

  def get_hurt
    @hp -= 1
    return @hp <= 0
  end

end

class Character
  attr_accessor :x
  attr_accessor :y

  def initialize
    @anim = Animation.new('game/idle.png')
    @shoot = Animation.new('game/shoot.png')

    @x = 0
    @y = 150
    @anim_speed = 20
    @shoot_speed = 10
    @button_rate = 40

  end
  def reset
    @x = 0
    @y = 150
    @anim_frame = 0
    @up_frame = 0
    @down_frame = 0
  end
  def update(btns)
    @still = true
    if btns.pressed?(:up)
      if @y > 0
        @y -= 75
      end
    end
    if btns.pressed?(:down)
      if @y < 150
        @y += 75
      end
    end
    if btns.held?(:up)
      @up_frame = (@up_frame + 1) % @button_rate
      if @up_frame / (@button_rate / 2) == 1
        if @y > 0
          @y -= 75
        end
      end
    else
      @up_frame = 0
    end
    if btns.held?(:down)
      @down_frame = (@down_frame + 1) % @button_rate
      if @down_frame / (@button_rate / 2) == 1
        if @y < 150
          @y += 75
        end
      end
    else
      @down_frame = 0
    end

    if btns.held?(:shoot)
      @still = false
      @anim_frame = (@anim_frame + 1) % @shoot_speed
    else
      @anim_frame = (@anim_frame + 1) % @anim_speed
    end
    btns.framereset
  end

  def draw
    if @still
      frame = @anim_frame / (@anim_speed / 2)
      @anim.draw(frame, @x, @y, 5)
    else
      frame = @anim_frame / (@shoot_speed / 2)
      @shoot.draw(frame, @x, @y, 5)
    end
  end
end


class Screen < Gosu::Window
  attr_accessor :score
  def initialize
    super 320, 240
    self.caption="Spider Killing Machine"

    @bg = Gosu::Image.new('game/bg.png')
    @char = Character.new
    @dead_char = Gosu::Image.new ('game/dead.png')
    @bullet = Gosu::Image.new('game/bullet.png')
    @song = Gosu::Song.new('game/metal.ogg')
    @losesong = Gosu::Song.new('game/losesong.ogg')
    @losesound = Gosu::Sample.new('game/no.ogg')

    @text = Gosu::Font.new(20)


    @buttons = Buttons.new

  end

  def reset
    @dead = false
    @dead_timer = 0
    @score = 0
    @bullet_frame = 0
    @frame = 0
    @interval = 2.0

    if @losesong.playing?
      @losesong.stop
    end
    @song.play(true)

    @spiders = []
    @bullets = []

    @buttons.reset
    @char.reset
  end
  # Buttons
  def button_symbol(id)
    case id
    when Gosu::KbUp, Gosu::KbW
      return :up
    when Gosu::KbDown, Gosu::KbS
      return :down
    when Gosu::KbSpace
      return :shoot
    else
      return nil
    end
  end

  def button_down(id)
    @buttons.press(button_symbol id)
    if @dead
      if @dead_timer >= 60 * 1.2
        self.reset
      end
    end
  end

  def button_up(id)
    @buttons.release(button_symbol id)
  end

  def update
    if !@dead
      @char.update(@buttons)

      @buttons.framereset
      #Speed of monster spawn
      i = 1
      while i < 10 do
        if @frame > (i * 60 * 5).to_i
          @interval = -0.2 * i + 2.2
        end
        i += 1
      end
      #Spawn monsters
      if interval? @interval
        case rand(3)
        when 0
          color = 'red'
          x = 260
          y = 25
          speed = 2
        when 1
          color = 'yellow'
          x = 260
          y = 100
          speed = 3
        when 2
          color = 'blue'
          x = 260
          y = 175
          speed = 4
        end
        @spiders << Spider.new(color, x, y, speed)
      end
      #Move monsters

      @spiders.each do |spider|
        spider.update
        if (spider.x - 65).abs < 16 #&& (spider.y - @char.y).abs < 16
          @song.stop
          @losesound.play

          @dead = true


        end
      end

      # Shooting
      if @buttons.held? :shoot
        if @bullet_frame % 8 == 0
      #        @shoot_sfx.play
          y = @char.y + 41
          x = 72
          @bullets << Bullet.new(@bullet, x, y)
        end
        @bullet_frame += 1
      else
        @bullet_frame = 0
      end

      # Update bullets, hit monsters
      @bullets.each do |bullet|
        @bullets.delete bullet if bullet.update
        @spiders.each do |spider|
          if bullet.x > spider.x && bullet.x < spider.x + 32 \
          && bullet.y > spider.y && bullet.y < spider.y + 32
            @bullets.delete bullet
            if spider.get_hurt
  #               @explode_sfx.play
              @score += 1
              @spiders.delete spider
            else
  #           @hit_sfx.play
            end
          end
        end
      end
    end

    @frame += 1

    if @dead_timer >= 60 * 1.2
      @losesong.play(false)
    end
  end

  def draw
  # do stuff
    @bg.draw(0,0,0)
    @char.draw unless @dead
    @spiders.each { |m| m.draw }
    @bullets.each { |m| m.draw }
    @text.draw("Score: " + @score.to_s, 0, 0, 100) unless @dead
    if @dead
      @dead_char.draw(@char.x,@char.y,5)
      @dead_timer += 1
      if @dead_timer >= 60 * 1.2
        @final_score = Gosu::Image.from_text("Final Score: " + @score.to_s, 40, {:font => 'game/CHILLER.TTF', :align => :center})
        @final_score.draw((320 - @final_score.width) / 2, (240 - @final_score.height)/2, 100)
        @final_message = Gosu::Image.from_text("Press any key to play again", 25, {:font => 'game/CHILLER.TTF', :align => :center})
        @final_message.draw((320 - @final_message.width) / 2, (240 - @final_message.height)/2 + 20, 100)

      end
    end

  end

  def interval?(seconds)
    @frame % (seconds * 60).to_i == 0
  end

end

window = Screen.new
window.reset
window.show
