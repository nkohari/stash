expect = require('chai').expect
Stash  = require '../src/Stash'

describe 'When no dependencies exist', ->
	stash = new Stash()
	
	beforeEach ->
		stash.set 1, {id: 1, text: 'foo'}
		stash.set 2, {id: 2, text: 'bar'}

	afterEach ->
		stash.redis.del 1, 2
	
	it 'should delete only the invalidated entry', (done) ->
		stash.inv 1, (err, invalid) ->
			expect(invalid).to.be.eql [1]
			done()

describe 'When a single dependency exists', ->
	stash = new Stash()
	
	beforeEach ->
		obj1 = {id: 1, text: 'foo'}
		obj2 = {id: 2, text: 'bar'}
		arrA = [obj1, obj2]
		
		stash.set 1,   obj1
		stash.set 2,   obj2
		stash.set 'A', arrA
		stash.dep 'A', [1, 2]
	
	afterEach ->
		stash.redis.del 1, 2, 'A', stash._depkey(1), stash._depkey(2)
	
	it 'should invalidate the dependency', (done) ->
		stash.inv 1, (err, invalid) ->
			expect(invalid).to.be.eql [1, 'A']
			done()

describe 'When two levels of dependencies exist', ->
	stash = new Stash()
	
	beforeEach ->
		obj1 = {id: 1, text: 'foo'}
		obj2 = {id: 2, text: 'bar'}
		arrA = [obj1, obj2]
		arrB = [obj2]
		arrC = [arrA, arrB]
		
		stash.set 1,   obj1
		stash.set 2,   obj2
		stash.set 'A', arrA
		stash.dep 'A', [1, 2]
		stash.set 'B', arrB
		stash.dep 'B', 2
		stash.set 'C', arrC
		stash.dep 'C', ['A', 'B']
	
	afterEach ->
		stash.redis.del 1, 2, 'A', 'B', 'C', stash._depkey(1), stash._depkey(2), stash._depkey('A'), stash._depkey('B')
	
	it 'should invalidate all dependencies', (done) ->
		stash.inv 1, (err, invalid) ->
			expect(invalid).to.be.eql [1, 'A', 'C']
			done()
