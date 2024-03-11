pa rubywrapper

fu! NyaoBoxesFzfSink(line)
  let g:nyao_boxes_lines = a:line
endfu

fu! s:NyaoBoxesSetup()
ruby << NYAOBOXES
class Array
  def fzf
    io = IO.popen('fzf -m', 'r+')
    begin
      stdout, $stdout = $stdout, io
      each { puts _1 } rescue nil
    ensure
      $stdout = stdout
    end
    io.close_write
    io.readlines.map(&:chomp)
  end

  def fzf2
    # Ev.NyaoBoxesFzf self
    Ev.send(
      "fzf#run",
      {
        'source': self,
        'sink': '{ line -> NyaoBoxesFzfSink(line) }'.lit,
        'options': '--with-nth=3.. --delimiter="\\:" --preview="bat --color=always --style=numbers --line-range={2}: {1}"'
      }
    )
  end
end

require 'json'

module NyaoBoxes
  def self.start
    load
  end

  def self.update_dwarfrc name
    unless File.exist? ENV["HOME"] + "/dwarfboxes"
      Dir.mkdir ENV["HOME"] + "/dwarfboxes"
    end

    File.write(
      ENV["HOME"] + "/.dwarfrc",
      "storage_file: dwarfboxes/" + name
    )
  end

  def self.select_box
    boxes = data.keys - ["current_box"]
    data["current_box"] = boxes.fzf.first
    save
    update_dwarfrc data["current_box"]
    Ev.DrawDwarfCodebase
    Ex.redraw!
  end

  def self.current_box
    data[ data["current_box"] ] || data[ (data.keys - ["current_box"]).first ]
  end

  def self.look_in_current_box
    return unless current_box

    Global.nyao_boxes_lines = nil

    current_box.map do |item|
      nr = nil
      if File.exist? item["fname"]
        nr = File.readlines( item["fname"] ).index do |l|
          l.include? item["line"]
        end
      end
      nr = nr ? (nr+1) : item["nr"]
      "#{ item['fname'] }:#{ nr }:#{ item['line'] }"
    end.fzf2

    line = Global.nyao_boxes_lines&.split(":")
    return unless line

    nr = nil
    if File.exist? line[0]
      nr = File.readlines( line[0] ).index do |l|
        l.include? line[2]
      end
    end
    nr = nr ? (nr+1) : line[1]

    # item = box.find{ _1["line"] == line }
    # return unless item

    # Ex.edit item["fname"]
    # Ev.search ('^\M'+item["line"]+'$').sq
    Ex.edit line[0]
    Ex.norm! nr.to_s+'ggzz'
    Ex.redraw!
  end

  def self.new_box
    n = Ev.input("Name Box: ")
    return if n.empty?
    data[n] = [] unless data[n]
    data["current_box"] = n
    save
  end

  def self.new_item
    line  = Ev.getline('.')
    nr    = Ev.line('.')
    fname = Ev.expand('%:p')
    item = {
      "line" => line,
      "nr" => nr,
      "fname" => fname
    }
    existing_item = current_box.find{|x| x["line"] == item["line"] && x["fname"] == item["fname"] }

    if existing_item
      existing_item["nr"] = item["nr"]
    else
      current_box << item
    end

    save
  end

  @data = {}
  @dir = "#{ENV["HOME"]}/.nyao"
  @path = "#{ENV["HOME"]}/.nyao/boxes.json"

  def self.data = @data
  def self.save = File.write @path, JSON.pretty_generate(@data)

  def self.load
    unless File.exist? @path
      Dir.mkdir @dir unless File.exist? @dir
      File.write @path, "{}"
    end

    @data = JSON.parse(File.read(@path))
  end
end

NyaoBoxes.start
NYAOBOXES
endfu

call s:NyaoBoxesSetup()

nno ,, :ruby NyaoBoxes.new_item<CR>
nno <space>, :ruby NyaoBoxes.look_in_current_box<CR>
nno <leader>, :ruby NyaoBoxes.select_box<CR>
nno <leader><leader>, :ruby NyaoBoxes.new_box<CR>
