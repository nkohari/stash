class window.StashVisualizer
	
	constructor: (el) ->
		@el = $(el)
		@canvas = @el.get(0)
		@system = arbor.ParticleSystem()
		@gfx = arbor.Graphics(@canvas)
		@system.renderer = this
	
	graph: (items) ->
		@system.graft items
	
	init: ->
		@system.screenSize @el.width(), @el.height()
		@system.parameters {gravity: true}
		@system.screenPadding(80)
	
	redraw: ->
		@gfx.clear()
		
		@system.eachEdge (edge, pos1, pos2) =>
			@gfx.line pos1, pos2, {stroke: '#999999', width: 2}
		
		@system.eachNode (node, pos) =>
			width = Math.max 20, 20 + @gfx.textWidth(node.name)
			@gfx.oval pos.x - width/2, pos.y - width/2, width, width, {fill: '#333333'}
			@gfx.text node.name, pos.x, pos.y, {color: 'white', align: 'center', font: 'Helvetica Neue', size: 14}
