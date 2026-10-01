=begin
VF 变量查找器（极简无注释版）  for RPG Maker VX Ace / RGSS3
用法：F6 开关；F8 跳页；F9 打字检索；F10 或键盘 A/S 键＝选字检索（中文）。
详细说明请看另一个文件 VF_变量查找器.rb 开头的说明段。
=end

module VF
  ENABLE_HOTKEY     = true
  ENABLE_IN_RELEASE = false
  SCAN_MAPS         = true
  SCAN_COMMON       = true
  SCAN_TROOPS       = true
  MAX_PER_VAR       = 200
  CHAR_LIST_MAX     = 0
  def self.pick_key(*names)
    names.each { |n| return n if Input.const_defined?(n) }
    nil
  end
  OPEN_KEY   = pick_key(:F6, :A)
  RESCAN_KEY = pick_key(:F5)
  SCOPE_KEY  = pick_key(:F7)
  PAGE_KEY   = pick_key(:F8)
  FIND_KEY   = pick_key(:F9)
  KEY_LABELS = {
    :F5 => "F5", :F6 => "F6", :F7 => "F7", :F8 => "F8", :F9 => "F9", :F10 => "F10",
    :X  => "A键", :Y => "S键", :Z => "D键", :L => "Q", :R => "W", :A => "Shift"
  }
  def self.key_label(key)
    key.nil? ? "" : (KEY_LABELS[key] || key.to_s)
  end
  def self.hint_text(key, desc)
    label = key.is_a?(String) ? key : key_label(key)
    label.empty? ? "" : "#{label}:#{desc}  "
  end
  CHAR_KEYS = [:F10, :X, :Y].select { |k| Input.const_defined?(k) }
  CHAR_KEYS << :A if Input.const_defined?(:A) && OPEN_KEY != :A
  def self.char_key?
    CHAR_KEYS.any? { |k| Input.trigger?(k) }
  end
  def self.char_key_label
    CHAR_KEYS.first(2).map { |k| key_label(k) }.join("/")
  end
  OP_NAME  = ["代入", "加算", "减算", "乘算", "除算", "取余"]
  CMP_NAME = ["==", ">=", "<=", ">", "<", "!="]
  KIND_NAME = {
    :command        => "变量操作",
    :condition      => "条件分支",
    :page_condition => "出现条件",
    :text           => "文本显示",
    :script         => "脚本指令",
    :operand        => "被读取"
  }
  JUMP_KEYS = {}
  (0..9).each do |d|
    JUMP_KEYS[:"NUM#{d}"]    = d if Input.const_defined?(:"NUM#{d}")
    JUMP_KEYS[:"NUMPAD#{d}"] = d if Input.const_defined?(:"NUMPAD#{d}")
  end
  KB_CHARS = {
    0x41 => ["a", "A"], 0x42 => ["b", "B"], 0x43 => ["c", "C"], 0x44 => ["d", "D"],
    0x45 => ["e", "E"], 0x46 => ["f", "F"], 0x47 => ["g", "G"], 0x48 => ["h", "H"],
    0x49 => ["i", "I"], 0x4A => ["j", "J"], 0x4B => ["k", "K"], 0x4C => ["l", "L"],
    0x4D => ["m", "M"], 0x4E => ["n", "N"], 0x4F => ["o", "O"], 0x50 => ["p", "P"],
    0x51 => ["q", "Q"], 0x52 => ["r", "R"], 0x53 => ["s", "S"], 0x54 => ["t", "T"],
    0x55 => ["u", "U"], 0x56 => ["v", "V"], 0x57 => ["w", "W"], 0x58 => ["x", "X"],
    0x59 => ["y", "Y"], 0x5A => ["z", "Z"],
    0x30 => ["0", ")"], 0x31 => ["1", "!"], 0x32 => ["2", "@"], 0x33 => ["3", "#"],
    0x34 => ["4", "$"], 0x35 => ["5", "%"], 0x36 => ["6", "^"], 0x37 => ["7", "&"],
    0x38 => ["8", "*"], 0x39 => ["9", "("],
    0x60 => ["0", "0"], 0x61 => ["1", "1"], 0x62 => ["2", "2"], 0x63 => ["3", "3"],
    0x64 => ["4", "4"], 0x65 => ["5", "5"], 0x66 => ["6", "6"], 0x67 => ["7", "7"],
    0x68 => ["8", "8"], 0x69 => ["9", "9"],
    0x20 => [" ", " "],
    0xBD => ["-", "_"], 0xBE => [".", ">"], 0xBC => [",", "<"],
    0xBA => [";", ":"], 0xDE => ["'", "\""], 0xDB => ["[", "{"], 0xDD => ["]", "}"],
    0xDC => ["\\", "|"], 0xBF => ["/", "?"], 0xC0 => ["`", "~"], 0xBB => ["=", "+"]
  }
  KB_BACKSPACE = 0x08
  KB_ENTER     = 0x0D
  KB_ESC       = 0x1B
  KB_SHIFTS    = [0x10, 0xA0, 0xA1]
  Usage = Struct.new(:vid, :kind, :place, :note)
  class << self
    attr_reader :index, :var_names
    def ensure_index(force = false)
      build_index if force || @index.nil?
      @index
    end
    def build_index
      @index      = {}
      @total      = {}
      @used_cache = nil
      @var_names  = ($data_system && $data_system.variables) ? $data_system.variables : []
      scan_maps   if SCAN_MAPS
      scan_common if SCAN_COMMON
      scan_troops if SCAN_TROOPS
      @index
    end
    def add(vid, kind, place, note)
      vid = vid.to_i
      return if vid < 0
      list = (@index[vid] ||= [])
      @total[vid] = (@total[vid] || 0) + 1
      return if list.size >= MAX_PER_VAR
      list << Usage.new(vid, kind, place, note)
    end
    def usage(vid)
      (@index && @index[vid]) ? @index[vid] : []
    end
    def total_of(vid)
      (@total && @total[vid]) ? @total[vid] : 0
    end
    def used_ids
      return [] unless @index
      @used_cache ||= @index.keys.select { |k| !@index[k].empty? }.sort
    end
    def var_name(vid)
      return "" if vid.nil? || vid <= 0
      s = @var_names[vid]
      s.nil? ? "" : s.to_s
    end
    def var_total
      return 0 unless $data_system && $data_system.variables
      [$data_system.variables.size - 1, 0].max
    end
    def value_of(vid)
      return nil if vid.nil? || vid <= 0
      begin
        $game_variables[vid]
      rescue
        nil
      end
    end
    def value_text(vid)
      v = value_of(vid)
      v.nil? ? "—" : shorten(v.to_s, 16)
    end
    def label(vid)
      return "【脚本中的变量操作·编号未识别】" if vid.to_i == 0
      n = var_name(vid)
      n.empty? ? sprintf("%04d", vid) : sprintf("%04d %s", vid, n)
    end
    def shorten(s, n)
      s = s.to_s.gsub(/[\r\n]/, " ")
      s.length > n ? s[0, n - 1] + "…" : s
    end
    def blank_char?(c)
      c == " " || c == "\t" || c == "\n" || c == "\r" || c == "\u3000"
    end
    def fit(bitmap, str, max_width)
      s = str.to_s
      return s if s.empty?
      return s if bitmap.text_size(s).width <= max_width
      while s.length > 1 && bitmap.text_size(s + "…").width > max_width
        s = s[0, s.length - 1]
      end
      s + "…"
    end
    def load_data_safe(path)
      begin
        load_data(path)
      rescue
        nil
      end
    end
    def scan_maps
      infos = load_data_safe("Data/MapInfos.rvdata2")
      if infos.is_a?(Hash) && !infos.empty?
        ids = infos.keys.sort
      else
        ids = Dir.glob("Data/Map*.rvdata2").map { |f| File.basename(f)[/\d+/].to_i }.sort
      end
      ids.each do |map_id|
        next if map_id.to_i <= 0
        map = load_data_safe(sprintf("Data/Map%03d.rvdata2", map_id))
        next unless map && map.respond_to?(:events) && map.events
        info = infos.is_a?(Hash) ? infos[map_id] : nil
        map_name = (info && info.name) ? info.name.to_s : ""
        map_name = sprintf("地图%03d", map_id) if map_name.empty?
        map.events.each do |eid, event|
          next unless event && event.pages
          event.pages.each_with_index do |page, pi|
            place = sprintf("%s·事件%03d「%s」第%d页",
                            map_name, eid, shorten(event.name.to_s, 10), pi + 1)
            cond = page.condition
            if cond && cond.variable_valid && cond.variable_id.to_i > 0
              add(cond.variable_id, :page_condition, place,
                  sprintf("出现条件：变量%04d ≥ %d", cond.variable_id, cond.variable_value))
            end
            scan_commands(page.list, place)
          end
        end
      end
    end
    def scan_common
      list = load_data_safe("Data/CommonEvents.rvdata2")
      return unless list.is_a?(Array)
      list.each_with_index do |ce, i|
        next unless ce && ce.respond_to?(:list)
        place = sprintf("公共事件%03d「%s」", i, shorten(ce.name.to_s, 14))
        scan_commands(ce.list, place)
      end
    end
    def scan_troops
      troops = load_data_safe("Data/Troops.rvdata2")
      return unless troops.is_a?(Array)
      troops.each_with_index do |troop, i|
        next unless troop && troop.respond_to?(:pages) && troop.pages
        troop.pages.each_with_index do |page, pi|
          place = sprintf("敌群%03d「%s」战斗事件第%d页",
                          i, shorten(troop.name.to_s, 14), pi + 1)
          scan_commands(page.list, place)
        end
      end
    end
    def scan_commands(list, place)
      return unless list.is_a?(Array)
      list.each_with_index do |cmd, i|
        next unless cmd
        p = cmd.parameters || []
        line = sprintf("第%d条", i + 1)
        case cmd.code
        when 122
          scan_var_command(p, place, line)
        when 111
          scan_branch(p, place, line)
        when 355, 655
          scan_script_line(p[0].to_s, place, line) if p[0]
        when 101, 102, 108, 401, 402, 405, 408
          scan_text(p, place, line)
        end
      end
    end
    def scan_var_command(p, place, line)
      return if p.size < 2
      first = p[0].to_i
      last  = p[1].to_i
      return if first <= 0
      last = first if last < first
      op      = p[2].to_i
      otype   = p.size > 3 ? p[3].to_i : 0
      oval    = p[4]
      op_name = OP_NAME[op] || "操作#{op}"
      operand = operand_text(otype, oval)
      (first..last).each do |vid|
        add(vid, :command, place, sprintf("%s：变量%04d %s %s", line, vid, op_name, operand))
      end
      if otype == 1 && oval.to_i > 0 && (oval.to_i < first || oval.to_i > last)
        add(oval.to_i, :operand, place,
            sprintf("%s：被「变量%04d %s」读取", line, first, op_name))
      end
    end
    def operand_text(otype, oval)
      case otype
      when 0 then "常量 #{oval}"
      when 1 then sprintf("变量%04d", oval.to_i)
      when 2
        oval.is_a?(Array) ? sprintf("随机数 %s~%s", oval[0], oval[1]) : "随机数"
      when 3 then "游戏数据 #{oval.inspect}"
      when 4 then sprintf("脚本「%s」", shorten(oval.to_s, 24))
      else "未知"
      end
    end
    def scan_branch(p, place, line)
      return if p.empty?
      case p[0].to_i
      when 1
        vid = p[1].to_i
        return if vid <= 0
        otype = p.size > 2 ? p[2].to_i : 0
        oval  = p[3]
        cmp   = CMP_NAME[p[4].to_i] || "?"
        rhs   = (otype == 1) ? sprintf("变量%04d", oval.to_i) : oval.to_s
        add(vid, :condition, place,
            sprintf("%s：条件分支 变量%04d %s %s", line, vid, cmp, rhs))
        if otype == 1 && oval.to_i > 0 && oval.to_i != vid
          add(oval.to_i, :operand, place,
              sprintf("%s：被「变量%04d %s …」条件读取", line, vid, cmp))
        end
      when 12
        scan_script_line(p[1].to_s, place, line) if p[1]
      end
    end
    def scan_text(p, place, line)
      p.each do |s|
        next unless s.is_a?(String)
        s.scan(/\\[Vv]\[(\d+)\]/).flatten.each do |n|
          vid = n.to_i
          next if vid <= 0
          add(vid, :text, place,
              sprintf("%s：文本显示 \\V[%d] → %s", line, vid, shorten(s, 36)))
        end
      end
    end
    def scan_script_line(text, place, line)
      return if text.nil? || text.empty?
      return unless text.include?("game_variable")
      ids = text.scan(/game_variables\s*\[\s*(\d+)\s*\]/).flatten.map { |n| n.to_i }
      ids.uniq!
      ids.delete(0)
      if ids.empty?
        add(0, :script, place,
            sprintf("%s：脚本中操作变量（编号无法静态判断）：%s", line, shorten(text, 32)))
      else
        ids.each do |vid|
          add(vid, :script, place,
              sprintf("%s：脚本 $game_variables[%d]：%s", line, vid, shorten(text, 30)))
        end
      end
    end
    def can_open?
      return false unless $data_system && $game_variables
      return false unless $TEST || ENABLE_IN_RELEASE
      return false unless VF.const_defined?(:SceneFinder)
      !SceneManager.scene_is?(VF::SceneFinder)
    end
    def open
      return unless can_open?
      SceneManager.call(VF::SceneFinder)
    end
    def hotkey_check
      return unless ENABLE_HOTKEY
      return false if OPEN_KEY.nil?
      return unless Input.trigger?(OPEN_KEY)
      open
    end
    def keyboard_available?
      init_keyboard
      @kb_ok ? true : false
    end
    def init_keyboard
      return @kb_ok unless @kb_ok.nil?
      @kb_ok   = false
      @kb_prev = {}
      begin
        @kb = Win32API.new("user32", "GetAsyncKeyState", "I", "I")
        @kb.call(0x41)
        @kb_ok = true
      rescue
        @kb_ok = false
      end
      @kb_ok
    end
    def kb_down?(vk)
      (@kb.call(vk) & 0x8000) != 0
    rescue
      @kb_ok = false
      false
    end
    def kb_reset
      return unless @kb_ok
      @kb_prev = {}
      keys = KB_CHARS.keys + KB_SHIFTS + [KB_BACKSPACE, KB_ENTER, KB_ESC]
      keys.each { |vk| @kb_prev[vk] = kb_down?(vk) }
    end
    def kb_poll_events
      return [] unless keyboard_available?
      @kb_prev ||= {}
      events = []
      shift = false
      KB_SHIFTS.each { |vk| shift = true if kb_down?(vk) }
      KB_CHARS.each do |vk, pair|
        down = kb_down?(vk)
        events << (shift ? pair[1] : pair[0]) if down && !@kb_prev[vk]
        @kb_prev[vk] = down
      end
      [[KB_BACKSPACE, :backspace], [KB_ENTER, :enter], [KB_ESC, :esc]].each do |vk, sym|
        down = kb_down?(vk)
        events << sym if down && !@kb_prev[vk]
        @kb_prev[vk] = down
      end
      events
    end
  end
  INSTALL_UI = lambda do
    class WindowHeader < Window_Base
      def initialize
        lh  = line_height
        pad = standard_padding
        super(0, 0, 544, lh * 3 + pad * 2)
        @lines = ["", "", ""]
        refresh
      end
      def set_lines(a, b, c)
        @lines = [a.to_s, b.to_s, c.to_s]
        refresh
      end
      def refresh
        return if contents.nil? || contents.disposed?
        lh = line_height
        contents.clear
        colors = [text_color(6), normal_color, system_color]
        @lines.each_with_index do |s, i|
          next if s.empty?
          change_color(colors[i] || normal_color)
          draw_text(0, i * lh, contents.width, lh, VF.fit(contents, s, contents.width))
        end
        change_color(normal_color)
      end
    end
    class WindowList < Window_Selectable
      def initialize(x, y, width, height, row_height, mode, cols = 1)
        @row_height = row_height
        @mode       = mode
        @cols       = cols
        @data       = []
        super(x, y, width, height)
        refresh
      end
      def item_max
        @data ? @data.size : 0
      end
      def item_height
        @row_height
      end
      def col_max
        @cols
      end
      def spacing
        @mode == :chars ? 0 : 4
      end
      def contents_height
        n = item_max
        n = 1 if n < 1
        rows = (n + col_max - 1) / col_max
        rows * item_height
      end
      def data
        @data
      end
      def current_item
        (@data && index && index >= 0 && index < @data.size) ? @data[index] : nil
      end
      def select(index)
        self.index = index if index
      end
      def set_data(rows)
        @data = rows || []
        refresh
        select(item_max > 0 ? 0 : -1)
      end
      def process_cursor_move
      end
      def process_handling
      end
      def refresh
        create_contents
        return if contents.nil? || contents.disposed?
        contents.clear
        draw_all_items
      end
      def draw_all_items
        item_max.times { |i| draw_item(i) }
      end
      def draw_item(i)
        case @mode
        when :vars
          draw_var_row(i, @data[i])
        when :usage
          draw_usage_row(i, @data[i])
        else
          draw_char_cell(i, @data[i])
        end
      end
      def draw_var_row(i, vid)
        return if vid.nil?
        lh   = line_height
        rect = item_rect(i)
        change_color(system_color)
        draw_text(rect.x, rect.y, 48, lh, sprintf("%04d", vid))
        name = VF.var_name(vid)
        name = "（未命名）" if name.empty? && vid.to_i != 0
        name = "脚本中的变量操作" if vid.to_i == 0
        change_color(normal_color)
        draw_text(rect.x + 52, rect.y, 214, lh, VF.fit(contents, name, 214))
        change_color(power_up_color)
        draw_text(rect.x + 266, rect.y, 168, lh, "值: " + VF.value_text(vid))
        n = VF.total_of(vid)
        change_color(normal_color, n > 0)
        draw_text(rect.x + 436, rect.y, 84, lh, sprintf("用%d处", n), 2)
        change_color(normal_color)
      end
      def draw_usage_row(i, u)
        return if u.nil?
        lh   = line_height
        rect = item_rect(i)
        w    = rect.width - 28
        change_color(system_color)
        draw_text(rect.x + 2, rect.y, 24, lh, sprintf("%d", i + 1))
        change_color(normal_color)
        draw_text(rect.x + 28, rect.y, w, lh, VF.fit(contents, u.place, w))
        change_color(text_color(3))
        kind = KIND_NAME[u.kind] || u.kind.to_s
        draw_text(rect.x + 28, rect.y + lh, w, lh,
                  VF.fit(contents, "[" + kind + "] " + u.note, w))
        change_color(normal_color)
      end
      def draw_char_cell(i, item)
        return if item.nil?
        ch   = item.is_a?(Array) ? item[0].to_s : item.to_s
        rect = item_rect(i)
        fs   = contents.font.size
        fs   = 20 if fs.nil? || fs <= 0
        y    = rect.y + [(item_height - fs) / 2, 0].max
        change_color(normal_color)
        draw_text(rect.x, y, rect.width, item_height, ch, 1)
        change_color(normal_color)
      end
    end
    class SceneFinder < Scene_MenuBase
      def start
        super
        @mode        = :vars
        @only_used   = true
        @var_ids     = []
        @usage_rows  = []
        @usage_vid   = 0
        @var_page    = 0
        @usage_page  = 0
        @char_items  = []
        @char_page   = 0
        @filter      = ""
        @input_mode  = nil
        @page_buffer = ""
        @input_wait  = 0
        @notice      = ""
        @notice_wait = 0
        @jump_buffer = ""
        @jump_wait   = 0
        @cache_valid = false
        @char_prev_only_used = nil
        @char_name_count     = 0
        @char_truncated      = false
        create_header_window
        wait_message("正在扫描工程数据……") { VF.ensure_index }
        create_list_windows
        rebuild_var_list
        refresh_header
      end
      def terminate
        super
        @header_window.dispose if @header_window
        @var_window.dispose    if @var_window
        @usage_window.dispose  if @usage_window
        @char_window.dispose   if @char_window
      end
      def create_header_window
        @header_window = WindowHeader.new
      end
      def create_list_windows
        lh   = @header_window.line_height
        pad  = @header_window.standard_padding
        top  = lh * 3 + pad * 2
        list_h = [416 - top, lh * 2 + pad * 2].max
        @char_cols = char_columns
        @var_window   = WindowList.new(0, top, 544, list_h, lh,     :vars,  1)
        @usage_window = WindowList.new(0, top, 544, list_h, lh * 2, :usage, 1)
        @char_window  = WindowList.new(0, top, 544, list_h, lh,     :chars, @char_cols)
        @vars_per_page  = page_count_of(@var_window)
        @usage_per_page = page_count_of(@usage_window)
        @char_per_page  = page_count_of(@char_window)
        @usage_window.visible = false
        @usage_window.active  = false
        @char_window.visible  = false
        @char_window.active   = false
        @var_window.visible   = true
        @var_window.active    = true
      end
      def page_count_of(win)
        rows = win.respond_to?(:page_row_max) ? win.page_row_max : 0
        if rows.nil? || rows <= 0
          rows = (win.height - win.standard_padding * 2) / win.item_height
        end
        rows = 1 if rows < 1
        rows * win.col_max
      end
      def char_columns
        pad = @header_window.standard_padding
        fs  = @header_window.contents.font.size
        fs  = 20 if fs.nil? || fs <= 0
        n = (544 - pad * 2) / (fs + 6)
        n = 4  if n < 4
        n = 24 if n > 24
        n
      end
      def wait_message(text)
        lh  = @header_window.line_height
        pad = @header_window.standard_padding
        w = Window_Base.new(0, 152, 544, lh * 2 + pad * 2)
        w.contents.draw_text(0, 0, w.contents.width, lh, text)
        w.contents.draw_text(0, lh, w.contents.width, lh, "地图较多时需要几秒，期间画面会静止")
        Graphics.update
        yield
        w.dispose
      end
      def return_scene
        SceneManager.return
      end
      def update
        super
        @header_window.update
        @var_window.update
        @usage_window.update
        @char_window.update
        update_notice
        if @input_mode == :page
          update_page_input
        elsif @input_mode == :find
          update_find_input
        elsif @mode == :chars
          update_char_input
        elsif @mode == :usage
          update_usage_input
          update_func_keys(false)
        else
          update_var_input
          update_jump_input
          update_func_keys(true)
        end
      end
      def update_notice
        if @notice_wait > 0
          @notice_wait -= 1
          refresh_header if @notice_wait == 0
        end
      end
      def set_notice(text, frames = 180)
        @notice      = text
        @notice_wait = frames
        refresh_header
      end
      def poll_events(typed_only)
        if typed_only
          return VF.keyboard_available? ? VF.kb_poll_events : []
        end
        events = []
        events.concat(VF.kb_poll_events) if VF.keyboard_available?
        JUMP_KEYS.each { |key, digit| events << digit.to_s if Input.trigger?(key) }
        events.uniq
      end
      def update_func_keys(allow_find)
        if RESCAN_KEY && Input.trigger?(RESCAN_KEY)
          rescan
          return true
        end
        if OPEN_KEY && Input.trigger?(OPEN_KEY)
          Sound.play_cancel
          return_scene
          return true
        end
        if PAGE_KEY && Input.trigger?(PAGE_KEY)
          start_page_input
          return true
        end
        return false unless allow_find
        if FIND_KEY && Input.trigger?(FIND_KEY)
          start_find_input
          return true
        end
        if VF.char_key?
          enter_char_mode
          return true
        end
        false
      end
      def start_page_input
        @input_mode  = :page
        @page_buffer = ""
        @input_wait  = 0
        VF.kb_reset if VF.keyboard_available?
        Sound.play_ok
        refresh_header
      end
      def update_page_input
        if PAGE_KEY && Input.trigger?(PAGE_KEY)
          @input_mode = nil
          Sound.play_cancel
          refresh_header
          return
        end
        events = poll_events(false)
        digits = events.select { |e| e.is_a?(String) && e =~ /\A[0-9]\z/ }
        if digits.empty? && !VF.keyboard_available?
          if Input.trigger?(:B)
            @input_mode = nil
            Sound.play_cancel
            refresh_header
            return
          end
          if Input.trigger?(:C)
            do_page_jump(@page_buffer.to_i) unless @page_buffer.empty?
            @input_mode = nil
            refresh_header
            return
          end
        end
        events.each do |e|
          case e
          when :esc
            @input_mode = nil
            Sound.play_cancel
            refresh_header
            return
          when :enter
            do_page_jump(@page_buffer.to_i) unless @page_buffer.empty?
            @input_mode = nil
            refresh_header
            return
          when :backspace
            @page_buffer = @page_buffer[0, @page_buffer.length - 1].to_s
            refresh_header
          when String
            next unless e =~ /\A[0-9]\z/
            @page_buffer += e
            if @page_buffer.length > 3
              @page_buffer = @page_buffer[@page_buffer.length - 3, 3].to_s
            end
            @input_wait = 42
            Sound.play_cursor
            refresh_header
          end
        end
        if @input_wait > 0
          @input_wait -= 1
          if @input_wait == 0 && !@page_buffer.empty?
            do_page_jump(@page_buffer.to_i)
            @input_mode = nil
            refresh_header
          end
        end
      end
      def do_page_jump(n)
        return if n.nil? || n <= 0
        if @mode == :usage
          per   = @usage_per_page
          total = [(@usage_rows.size + per - 1) / per, 1].max
          n = total if n > total
          set_usage_cursor((n - 1) * per)
        elsif @mode == :chars
          per   = @char_per_page
          total = [(@char_items.size + per - 1) / per, 1].max
          n = total if n > total
          set_char_cursor((n - 1) * per)
        else
          per   = @vars_per_page
          total = [(@var_ids.size + per - 1) / per, 1].max
          n = total if n > total
          set_var_cursor((n - 1) * per)
        end
        Sound.play_ok
      end
      def start_find_input
        unless VF.keyboard_available?
          set_notice("本机 RGSS 无法读取键盘，打字检索不可用；请用 " +
                     VF.char_key_label + " 选字检索", 240)
          Sound.play_buzzer
          return
        end
        @input_mode = :find
        VF.kb_reset
        Sound.play_ok
        refresh_header
      end
      def update_find_input
        if FIND_KEY && Input.trigger?(FIND_KEY)
          @input_mode = nil
          Sound.play_ok
          refresh_header
          return
        end
        changed = false
        poll_events(true).each do |e|
          case e
          when :esc
            @input_mode = nil
            Sound.play_cancel
            refresh_header
            return
          when :enter
            @input_mode = nil
            Sound.play_ok
            refresh_header
            return
          when :backspace
            if @filter.empty?
              Sound.play_buzzer
            else
              @filter  = @filter[0, @filter.length - 1].to_s
              changed  = true
            end
          when String
            @filter += e
            changed = true
          end
        end
        return unless changed
        rebuild_all
        Sound.play_cursor
        refresh_header
      end
      def set_cursor_of(list, per_page, page_ivar, win, gi, reload_method)
        total = list.size
        return if total == 0
        gi = 0 if gi < 0
        gi = total - 1 if gi >= total
        new_page = gi / per_page
        if instance_variable_get(page_ivar) != new_page
          instance_variable_set(page_ivar, new_page)
          send(reload_method)
          Sound.play_cursor
        end
        pos = gi % per_page
        if win.index != pos
          win.select(pos)
          Sound.play_cursor
        end
      end
      def current_var_index
        @var_page * @vars_per_page + (@var_window.index || 0)
      end
      def set_var_cursor(gi)
        set_cursor_of(@var_ids, @vars_per_page, :@var_page, @var_window, gi, :load_var_page)
        refresh_header
      end
      def load_var_page
        rows = @var_ids[@var_page * @vars_per_page, @vars_per_page]
        @var_window.set_data(rows || [])
      end
      def current_usage_index
        @usage_page * @usage_per_page + (@usage_window.index || 0)
      end
      def set_usage_cursor(gi)
        set_cursor_of(@usage_rows, @usage_per_page, :@usage_page, @usage_window, gi, :load_usage_page)
        refresh_header
      end
      def load_usage_page
        rows = @usage_rows[@usage_page * @usage_per_page, @usage_per_page]
        @usage_window.set_data(rows || [])
      end
      def current_char_index
        @char_page * @char_per_page + (@char_window.index || 0)
      end
      def set_char_cursor(gi)
        set_cursor_of(@char_items, @char_per_page, :@char_page, @char_window, gi, :load_char_page)
        refresh_header
      end
      def load_char_page
        rows = @char_items[@char_page * @char_per_page, @char_per_page]
        @char_window.set_data(rows || [])
      end
      def update_var_input
        if Input.trigger?(:B)
          handle_cancel
          return
        end
        return if @var_ids.empty?
        gi = current_var_index
        if Input.repeat?(:DOWN)
          set_var_cursor(gi + 1)
        elsif Input.repeat?(:UP)
          set_var_cursor(gi - 1)
        end
        if Input.trigger?(:R)
          set_var_cursor(gi + @vars_per_page)
        elsif Input.trigger?(:L)
          set_var_cursor(gi - @vars_per_page)
        end
        if Input.trigger?(:C)
          if @jump_buffer.empty?
            open_usages(@var_window.current_item)
          else
            do_jump(@jump_buffer.to_i)
            @jump_buffer = ""
            @jump_wait   = 0
          end
        end
      end
      def handle_cancel
        if @filter.empty?
          Sound.play_cancel
          return_scene
        else
          @filter      = ""
          @jump_buffer = ""
          @jump_wait   = 0
          rebuild_all
          Sound.play_cancel
          refresh_header
        end
      end
      def update_jump_input
        JUMP_KEYS.each do |key, digit|
          next unless Input.trigger?(key)
          @jump_buffer += digit.to_s
          if @jump_buffer.length > 4
            @jump_buffer = @jump_buffer[@jump_buffer.length - 4, 4].to_s
          end
          @jump_wait = 42
          Sound.play_cursor
          refresh_header
          break
        end
        if @jump_wait > 0
          @jump_wait -= 1
          if @jump_wait == 0 && !@jump_buffer.empty?
            do_jump(@jump_buffer.to_i)
            @jump_buffer = ""
            refresh_header
          end
        end
      end
      def do_jump(id)
        return if id.nil? || id <= 0
        pos = @var_ids.index(id)
        if pos
          @notice = ""
          set_var_cursor(pos)
        else
          @notice = if @filter.empty?
                      sprintf("列表中没有变量 %d（它可能既没有命名、也没有被任何地方使用）", id)
                    else
                      sprintf("当前检索结果里没有变量 %d", id)
                    end
          @notice_wait = 180
          Sound.play_buzzer
        end
        refresh_header
      end
      def update_usage_input
        if Input.trigger?(:B)
          close_usages
          return
        end
        return if @usage_rows.empty?
        gi = current_usage_index
        if Input.repeat?(:DOWN)
          set_usage_cursor(gi + 1)
        elsif Input.repeat?(:UP)
          set_usage_cursor(gi - 1)
        end
        if Input.trigger?(:R)
          set_usage_cursor(gi + @usage_per_page)
        elsif Input.trigger?(:L)
          set_usage_cursor(gi - @usage_per_page)
        end
      end
      def open_usages(vid)
        return if vid.nil?
        @usage_vid  = vid
        @usage_rows = VF.usage(vid)
        @usage_page = 0
        @mode = :usage
        load_usage_page
        @var_window.visible   = false
        @var_window.active    = false
        @usage_window.visible = true
        @usage_window.active  = true
        Sound.play_ok
        refresh_header
      end
      def close_usages
        @mode = :vars
        @usage_window.visible = false
        @usage_window.active  = false
        @var_window.visible   = true
        @var_window.active    = true
        Sound.play_cancel
        refresh_header
      end
      def update_char_input
        if Input.trigger?(:B)
          char_backspace
          return
        end
        if VF.char_key?
          exit_char_mode
          return
        end
        return if update_func_keys(false)
        return if @char_items.empty?
        gi = current_char_index
        if Input.repeat?(:DOWN)
          set_char_cursor(gi + @char_cols)
        elsif Input.repeat?(:UP)
          set_char_cursor(gi - @char_cols)
        end
        if Input.trigger?(:RIGHT)
          set_char_cursor(gi + 1)
        elsif Input.trigger?(:LEFT)
          set_char_cursor(gi - 1)
        end
        if Input.trigger?(:R)
          set_char_cursor(gi + @char_per_page)
        elsif Input.trigger?(:L)
          set_char_cursor(gi - @char_per_page)
        end
        pick_char if Input.trigger?(:C)
      end
      def enter_char_mode
        @char_prev_only_used = @only_used
        if @filter.empty? && @only_used
          @only_used = false
          rebuild_var_list
        end
        rebuild_char_list
        if @char_items.empty?
          @only_used = @char_prev_only_used
          rebuild_var_list
          set_notice("没有可选的文字（工程里还没有给变量起名字）")
          Sound.play_buzzer
          return
        end
        @mode = :chars
        @char_window.visible  = true
        @char_window.active   = true
        @var_window.visible   = false
        @var_window.active    = false
        @usage_window.visible = false
        @usage_window.active  = false
        Sound.play_ok
        refresh_header
      end
      def exit_char_mode
        if @filter.empty? && @char_prev_only_used == true
          @only_used = true
          rebuild_var_list
        end
        @mode = :vars
        @char_window.visible = false
        @char_window.active  = false
        @var_window.visible  = true
        @var_window.active   = true
        Sound.play_ok
        refresh_header
      end
      def char_backspace
        if @filter.empty?
          exit_char_mode
        else
          @filter = @filter[0, @filter.length - 1].to_s
          rebuild_all
          Sound.play_cancel
          refresh_header
        end
      end
      def pick_char
        item = @char_window.current_item
        return if item.nil?
        ch = item.is_a?(Array) ? item[0].to_s : item.to_s
        return if ch.empty?
        @filter += ch
        rebuild_all
        Sound.play_ok
        if @char_items.empty?
          exit_char_mode
        else
          refresh_header
        end
      end
      def rebuild_all
        rebuild_var_list
        rebuild_char_list if @mode == :chars
      end
      def rebuild_var_list
        @var_ids  = build_var_ids
        @var_page = 0
        load_var_page
      end
      def filter_active?
        !@filter.empty?
      end
      def precompute
        return if @cache_valid
        max = [VF.var_total, 1].max
        VF.used_ids.each { |id| max = id if id > max }
        @max_id      = max
        @id_strings  = []
        @lower_names = []
        (0..max).each do |i|
          @id_strings[i]  = sprintf("%04d", i)
          @lower_names[i] = VF.var_name(i).downcase
        end
        @all_cache   = nil
        @cache_valid = true
      end
      def all_candidate_ids
        precompute
        @all_cache ||= begin
          used  = VF.used_ids
          named = (1..@max_id).select { |i| !@lower_names[i].empty? }
          (named + used).uniq.sort
        end
      end
      def build_var_ids
        if filter_active?
          f = @filter.downcase
          all_candidate_ids.select do |id|
            @id_strings[id].to_s.include?(f) || @lower_names[id].to_s.include?(f)
          end
        elsif @only_used
          VF.used_ids
        else
          all_candidate_ids
        end
      end
      def rebuild_char_list
        count = {}
        disp  = {}
        used_names = 0
        @var_ids.each do |vid|
          name = VF.var_name(vid)
          next if name.empty?
          used_names += 1
          seen = {}
          name.each_char do |c|
            next if VF.blank_char?(c)
            k = c.downcase
            next if seen[k]
            seen[k] = true
            count[k] = (count[k] || 0) + 1
            disp[k] = c if disp[k].nil?
          end
        end
        keys = count.keys.sort_by { |k| [-count[k], k] }
        if CHAR_LIST_MAX > 0 && keys.size > CHAR_LIST_MAX
          keys = keys[0, CHAR_LIST_MAX]
          @char_truncated = true
        else
          @char_truncated = false
        end
        @char_items     = keys.map { |k| [disp[k], count[k]] }
        @char_name_count = used_names
        @char_page  = 0
        load_char_page
      end
      def rescan
        wait_message("正在重新扫描工程数据……") { VF.ensure_index(true) }
        @cache_valid = false
        @all_cache   = nil
        rebuild_all
        refresh_header
      end
      def refresh_header
        if @input_mode == :page
          t, i, h = header_page_input
        elsif @input_mode == :find
          t, i, h = header_find_input
        elsif @mode == :chars
          t, i, h = header_chars
        elsif @mode == :usage
          t, i, h = header_usage
        else
          t, i, h = header_vars
        end
        h = @notice if @notice_wait > 0 && !@notice.empty?
        @header_window.set_lines(t, i, h)
      end
      def header_vars
        pages = [(@var_ids.size + @vars_per_page - 1) / @vars_per_page, 1].max
        cur   = @var_window.current_item
        if filter_active?
          title = sprintf("检索「%s」　·　匹配 %d 个变量", @filter, @var_ids.size)
          hint  = "数字:跳号  " +
                  VF.hint_text(FIND_KEY, "继续打字") +
                  VF.hint_text(VF.char_key_label, "选字") +
                  VF.hint_text(PAGE_KEY, "跳页") +
                  "Esc:清除"
        else
          title = sprintf("变量查找器　·　已使用 %d 个变量　·　变量总数 %d",
                          VF.used_ids.size, VF.var_total)
          hint  = "Enter:详情  " +
                  VF.hint_text(VF.char_key_label, "选字") +
                  VF.hint_text(PAGE_KEY, "跳页") +
                  VF.hint_text(FIND_KEY, "打字") +
                  "Esc:退出"
        end
        info = if cur.nil?
                 filter_active? ? "没有匹配的变量" : "（没有可显示的变量）"
               else
                 sprintf("第%d/%d页　%s　值: %s　使用 %d 处",
                         @var_page + 1, pages, VF.label(cur),
                         VF.value_text(cur), VF.total_of(cur))
               end
        [title, info, hint]
      end
      def header_usage
        name  = VF.var_name(@usage_vid)
        title = if @usage_vid.to_i == 0
                  "脚本中的变量操作（编号未识别）"
                elsif name.empty?
                  sprintf("变量 %04d", @usage_vid)
                else
                  sprintf("变量 %04d「%s」　当前值: %s",
                          @usage_vid, name, VF.value_text(@usage_vid))
                end
        pages = [(@usage_rows.size + @usage_per_page - 1) / @usage_per_page, 1].max
        info  = sprintf("共 %d 处使用　第%d/%d页",
                        VF.total_of(@usage_vid), @usage_page + 1, pages)
        if VF.total_of(@usage_vid) > @usage_rows.size
          info += sprintf("　(最多记录 %d 条)", MAX_PER_VAR)
        end
        [title, info,
         "Q/W:翻页  " + VF.hint_text(PAGE_KEY, "跳页") +
         VF.hint_text(RESCAN_KEY, "重扫") + "Esc:返回变量列表"]
      end
      def header_chars
        pages = [(@char_items.size + @char_per_page - 1) / @char_per_page, 1].max
        cur   = @char_window.current_item
        if @filter.empty?
          title = sprintf("选字检索　·　字表共 %d 个字（来自 %d 个变量名）",
                          @char_items.size, @char_name_count)
        else
          title = sprintf("选字检索　·　关键词「%s」　匹配 %d 个变量　·　剩余 %d 个字",
                          @filter, @var_ids.size, @char_items.size)
        end
        info = if cur.nil?
                 "没有可选的文字"
               else
                 sprintf("%s（%d 个变量名含此字）　第%d/%d页",
                         cur[0], cur[1], @char_page + 1, pages)
               end
        info += "　字表已截断" if @char_truncated
        [title, info,
         "方向键:移动 Enter:选字 Esc:退一格  " +
         VF.hint_text(VF.char_key_label, "完成")]
      end
      def header_page_input
        if @mode == :usage
          per, n, what = @usage_per_page, @usage_rows.size, "使用位置"
        elsif @mode == :chars
          per, n, what = @char_per_page, @char_items.size, "选字表"
        else
          per, n, what = @vars_per_page, @var_ids.size, "变量列表"
        end
        total = [(n + per - 1) / per, 1].max
        buf   = @page_buffer.empty? ? "_" : @page_buffer
        ["跳页", sprintf("%s 共 %d 页　跳到第 %s 页", what, total, buf),
         "0-9:输入  Backspace:删字  Enter:确定  Esc:取消"]
      end
      def header_find_input
        ["打字检索（英文/数字）",
         sprintf("关键词: %s_　匹配 %d 个变量", @filter, @var_ids.size),
         "直接打字  Backspace:删字  Enter:完成  " +
         VF.hint_text(FIND_KEY, "完成") + "Esc:退出"]
      end
    end
    class ::Scene_Base
      unless method_defined?(:vf_original_update)
        alias vf_original_update update
      end
      def update
        vf_original_update
        return if self.is_a?(VF::SceneFinder)
        VF.hotkey_check
      end
    end
  end
  class << self
    def install
      return if @installed
      @installed = true
      INSTALL_UI.call
    end
  end
end
if defined?(Window_Base) && defined?(Window_Selectable) &&
   defined?(Scene_MenuBase) && defined?(Scene_Base)
  VF.install
else
  module Graphics
    class << self
      unless method_defined?(:vf_original_update)
        alias vf_original_update update
      end
      def update
        VF.install
        vf_original_update
      end
    end
  end
end
