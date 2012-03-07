(function() {

  window.StashVisualizer = (function() {

    function StashVisualizer(el) {
      this.el = $(el);
      this.canvas = this.el.get(0);
      this.system = arbor.ParticleSystem();
      this.gfx = arbor.Graphics(this.canvas);
      this.system.renderer = this;
    }

    StashVisualizer.prototype.graph = function(items) {
      return this.system.graft(items);
    };

    StashVisualizer.prototype.init = function() {
      this.system.screenSize(this.el.width(), this.el.height());
      this.system.parameters({
        gravity: true
      });
      return this.system.screenPadding(80);
    };

    StashVisualizer.prototype.redraw = function() {
      var _this = this;
      this.gfx.clear();
      this.system.eachEdge(function(edge, pos1, pos2) {
        return _this.gfx.line(pos1, pos2, {
          stroke: '#999999',
          width: 2
        });
      });
      return this.system.eachNode(function(node, pos) {
        var width;
        width = Math.max(20, 20 + _this.gfx.textWidth(node.name));
        _this.gfx.oval(pos.x - width / 2, pos.y - width / 2, width, width, {
          fill: '#333333'
        });
        return _this.gfx.text(node.name, pos.x, pos.y, {
          color: 'white',
          align: 'center',
          font: 'Helvetica Neue',
          size: 14
        });
      });
    };

    return StashVisualizer;

  })();

}).call(this);
