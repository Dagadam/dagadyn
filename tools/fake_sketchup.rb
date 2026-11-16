# Una SketchUp finta, quanto basta per far girare il motore di DagaDyn fuori
# da SketchUp: matrici 4×4 vere (come Geom::Transformation, per colonne),
# gruppi con attributi, materiali, tag, operazioni contate.
require 'json'

class Numeric
  def degrees; self * Math::PI / 180.0; end
  def m; self * 39.37007874; end
end

module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0.0, y = 0.0, z = 0.0)
      x, y, z = x if x.is_a?(Array)
      @x = x.to_f; @y = y.to_f; @z = z.to_f
    end
    def transform(t); t.apply(self); end
    def distance(o); Math.sqrt((x - o.x)**2 + (y - o.y)**2 + (z - o.z)**2); end
    def to_a; [x, y, z]; end
    def clone; self.class.new(x, y, z); end
    def -(o); Vector3d.new(x - o.x, y - o.y, z - o.z); end
  end

  class Vector3d < Point3d
    def length; Math.sqrt(x * x + y * y + z * z); end
    def transform(t); t.apply_vec(self); end
  end

  class Transformation
    # m: 16 valori per colonne (m[12..14] = traslazione), come to_a di SketchUp
    def initialize(m = nil); @m = (m || [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]).map(&:to_f); end
    def to_a; @m.dup; end
    def at(r, c); @m[c * 4 + r]; end

    def *(o)
      out = Array.new(16, 0.0)
      4.times { |c| 4.times { |r| out[c * 4 + r] = (0..3).sum { |k| at(r, k) * o.at(k, c) } } }
      Transformation.new(out)
    end

    def apply(p)
      v = [p.x, p.y, p.z, 1.0]
      r = (0..3).map { |i| (0..3).sum { |k| at(i, k) * v[k] } }
      Point3d.new(r[0] / r[3], r[1] / r[3], r[2] / r[3])
    end

    def apply_vec(p)
      v = [p.x, p.y, p.z]
      r = (0..2).map { |i| (0..2).sum { |k| at(i, k) * v[k] } }
      Vector3d.new(*r)
    end

    def inverse
      a = (0..3).map { |r| (0..3).map { |c| at(r, c) } + (0..3).map { |c| r == c ? 1.0 : 0.0 } }
      4.times do |c|
        piv = (c..3).max_by { |r| a[r][c].abs }
        a[c], a[piv] = a[piv], a[c]
        d = a[c][c]
        a[c] = a[c].map { |x| x / d }
        4.times { |r| next if r == c; f = a[r][c]; a[r] = a[r].each_with_index.map { |x, i| x - f * a[c][i] } }
      end
      out = Array.new(16, 0.0)
      4.times { |r| 4.times { |c| out[c * 4 + r] = a[r][4 + c] } }
      Transformation.new(out)
    end

    def self.translation(v)
      new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, v.x, v.y, v.z, 1])
    end

    def self.scaling(p, sx, sy, sz)
      translation(p) * new([sx, 0, 0, 0, 0, sy, 0, 0, 0, 0, sz, 0, 0, 0, 0, 1]) * translation(Vector3d.new(-p.x, -p.y, -p.z))
    end

    def self.rotation(p, axis, ang)
      l = axis.length
      x = axis.x / l; y = axis.y / l; z = axis.z / l
      c = Math.cos(ang); s = Math.sin(ang); t = 1 - c
      r = new([t * x * x + c,     t * x * y + s * z, t * x * z - s * y, 0,
               t * x * y - s * z, t * y * y + c,     t * y * z + s * x, 0,
               t * x * z + s * y, t * y * z - s * x, t * z * z + c,     0,
               0, 0, 0, 1])
      translation(p) * r * translation(Vector3d.new(-p.x, -p.y, -p.z))
    end
  end

  class BoundingBox
    attr_reader :min, :max
    def initialize(min = nil, max = nil); @min = min; @max = max; end
    def empty?; @min.nil?; end
    def center; Point3d.new((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2); end
    def width; max.x - min.x; end
    def height; max.y - min.y; end
    def depth; max.z - min.z; end
    # come SketchUp: 0..7, prima i 4 in basso (x, poi y), poi i 4 in alto
    def corner(k)
      Point3d.new(k & 1 == 0 ? min.x : max.x, k & 2 == 0 ? min.y : max.y, k & 4 == 0 ? min.z : max.z)
    end
    def add(*pts)
      pts.flatten.each do |p|
        @min = @min ? Point3d.new([@min.x, p.x].min, [@min.y, p.y].min, [@min.z, p.z].min) : p.clone
        @max = @max ? Point3d.new([@max.x, p.x].max, [@max.y, p.y].max, [@max.z, p.z].max) : p.clone
      end
      self
    end
  end
end

X_AXIS = Geom::Vector3d.new(1, 0, 0)
Y_AXIS = Geom::Vector3d.new(0, 1, 0)
Z_AXIS = Geom::Vector3d.new(0, 0, 1)
ORIGIN = Geom::Point3d.new(0, 0, 0)
GL_LINE_STRIP = 3
GL_LINES = 1
MF_CHECKED = 1; MF_UNCHECKED = 0; MF_ENABLED = 0; MF_GRAYED = 2

module Sketchup
  def self.status_text=(s); $status = s; end
  def self.status_text; $status; end
  def self.platform; :platform_win; end
  def self.active_model; $model; end
  def self.require(p); Kernel.require(p); end
  def self.add_observer(_o); true; end

  class Color
    attr_reader :red, :green, :blue
    def initialize(r = 255, g = 255, b = 255); @red = r.to_i; @green = g.to_i; @blue = b.to_i; end
  end

  class Entity
    @@pid = 1000
    attr_reader :persistent_id
    def initialize; @persistent_id = (@@pid += 1); @attrs = {}; @valid = true; end
    def valid?; @valid; end
    def erase!; @valid = false; end
    def get_attribute(d, k, dflt = nil); (@attrs[d] || {}).fetch(k, dflt); end
    def set_attribute(d, k, v); ($model.ops_changes += 1) if $model; (@attrs[d] ||= {})[k] = v; end
    def attribute_dictionary(d); @attrs[d]; end
    def attribute_dictionaries; self; end
    def delete(d); @attrs.delete(d); end
  end

  class Material
    attr_accessor :name, :color, :alpha, :texture
    def initialize(name); @name = name; @color = Color.new; @alpha = 1.0; @valid = true; end
    def valid?; @valid; end
    def kill; @valid = false; end
    def display_name; @name; end
  end

  class Materials
    include Enumerable
    def initialize; @list = []; end
    def add(n); m = Material.new(n); @list << m; m; end
    def remove(m); m.kill; @list.delete(m); end
    def each(&b); @list.each(&b); end
    def unique_name(n); n; end
    def size; @list.size; end
  end

  class Layer
    attr_reader :name
    def initialize(n); @name = n; end
    def valid?; true; end
  end

  class Layers
    include Enumerable
    def initialize(names); @list = names.map { |n| Layer.new(n) }; end
    def [](k); k.is_a?(Integer) ? @list[k] : @list.find { |l| l.name == k }; end
    def each(&b); @list.each(&b); end
  end

  class Face < Entity
    attr_accessor :material, :back_material
  end

  class Entities
    include Enumerable
    def initialize(list = []); @list = list; end
    def each(&b); @list.each(&b); end
    def <<(e); @list << e; end
  end

  class ComponentDefinition
    attr_reader :instances, :entities, :bounds, :name
    def initialize(bounds, name = 'Def'); @bounds = bounds; @instances = []; @entities = Entities.new; @name = name; end
    def image?; false; end
  end

  class Drawingelement < Entity
    attr_accessor :layer
    attr_reader :hidden
    def hidden?; !!@hidden; end
    def hidden=(h); $model.need_op!; @hidden = h; end
    def model; $model; end
  end

  class Group < Drawingelement
    attr_reader :definition, :material
    attr_accessor :name, :parent
    def initialize(defn, tr)
      super()
      @definition = defn; @tr = tr; @name = ''; defn.instances << self; @layer = $model.layers[0]; @parent = $model
    end
    def transformation; @tr; end
    def transformation=(t); $model.need_op!; @tr = t; end
    def move!(t); @tr = t; end
    def material=(m); $model.need_op!; @material = m; end
    def layer=(l); $model.need_op!; @layer = l; end
  end
  class ComponentInstance < Group; end

  class SectionPlane < Drawingelement
    def initialize(plane); super(); @plane = plane; @layer = $model.layers[0]; end
    def get_plane; @plane.dup; end
    def set_plane(p); $model.need_op!; @plane = p; end
  end

  # Il «pick» finto: i percorsi sotto il mouse si mettono in $picks[[x, y]]
  class PickHelper
    def do_pick(x, y); @paths = ($picks || {})[[x, y]] || []; end
    def count; @paths.size; end
    def path_at(i); @paths[i]; end
  end

  class View
    attr_accessor :animation, :tooltip, :line_width, :line_stipple, :drawing_color
    attr_reader :drawn
    def pick_helper; PickHelper.new; end
    def draw(mode, pts); (@drawn ||= []) << [mode, pts]; end
    def invalidate; end
    def show_frame; end
    def model; $model; end
  end

  class Model
    attr_reader :definitions, :materials, :layers, :active_view, :selection, :ops, :rendering_options
    attr_accessor :ops_changes, :shadow_info, :open_op
    def initialize
      @definitions = []; @materials = Materials.new; @layers = Layers.new(%w[Untagged Muri Porte])
      @active_view = View.new; @selection = []; @ops = []; @ops_changes = 0; @open_op = nil
      @shadow_info = { 'DisplayShadows' => true }; @rendering_options = {}; @attrs = {}
    end
    def valid?; true; end
    def options; { 'UnitsOptions' => { 'LengthUnit' => 4 } }; end
    def entities; @entities ||= Entities.new; end         # il livello principale: qui vuoto
    def start_operation(name, _disable_ui = true, _next = false, transparent = false)
      @open_op = [name, transparent]; true
    end
    def commit_operation; @ops << @open_op if @open_op; @open_op = nil; true; end
    def abort_operation; @open_op = nil; true; end
    # Le modifiche al modello fuori da un'operazione: errore del motore
    def need_op!; raise 'modifica fuori da un\'operazione' unless @open_op || $allow_free; end
    def find_entity_by_persistent_id(pid)
      @definitions.each { |d| d.instances.each { |e| return e if e.persistent_id == pid } }
      ($sections || []).find { |s| s.persistent_id == pid }
    end
    def get_attribute(d, k, dflt = nil); (@attrs[d] || {}).fetch(k, dflt); end
    def set_attribute(d, k, v); (@attrs[d] ||= {})[k] = v; end
    def add_group(min, max, tr = Geom::Transformation.new, cls = Group)
      d = ComponentDefinition.new(Geom::BoundingBox.new(Geom::Point3d.new(*min), Geom::Point3d.new(*max)))
      @definitions << d
      cls.new(d, tr)
    end
  end

  class AppObserver; end
  class ModelObserver; end
  class SelectionObserver; end

  # Overlay come in SketchUp 2023+: tolto con il suo documento non è più
  # valido, e toccarlo solleva «invalid overlay».
  class Overlay
    attr_reader :overlay_id
    def initialize(id, _name, description: ''); @overlay_id = id; @valid = true; @enabled = false; end
    def valid?; @valid; end
    def kill!; @valid = false; end
    def enabled?; @enabled; end
    def enabled=(v); raise 'invalid overlay' unless @valid; @enabled = v; end
  end

  class OverlaysManager
    include Enumerable
    def initialize; @list = []; end
    def add(o); @list << o; true; end
    def each(&b); @list.each(&b); end
    def drop_all!; @list.each(&:kill!); @list.clear; end
  end
end

# Osservatori del modello e della selezione (la selezione è un Array)
class Sketchup::Model
  def overlays; @overlays ||= Sketchup::OverlaysManager.new; end
  def observers; @observers ||= []; end
  def add_observer(o); observers << o; true; end
  def remove_observer(o); !!observers.delete(o); end
  # File › Nuovo su Windows: lo stesso oggetto Model, ma osservatori e
  # Overlay del documento di prima staccati
  def new_document!
    observers.clear
    selection.observers.clear
    overlays.drop_all!
  end
end
class Array
  def observers; @observers ||= []; end
  def add_observer(o); observers << o; true; end
  def remove_observer(o); !!observers.delete(o); end
  def add(*e); concat(e.flatten); end
end

module UI
  # i timer non partono, tranne con $run_timers (allora subito)
  def self.start_timer(*_a, &b); b.call if $run_timers && b; 1; end
  def self.stop_timer(*_a); end
  def self.messagebox(*_a); end
  def self.create_cursor(path, x, y); ($cursors ||= []) << [path, x, y]; 76 + $cursors.size; end
  def self.set_cursor(id); $cursor = id; end
end
