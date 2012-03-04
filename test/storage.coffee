async  = require 'async'
expect = require('chai').expect
Stash  = require '../src/Stash'

describe 'Given a stash', ->
	stash = new Stash()
	
	afterEach (ready) ->
		stash.rem 'foo', ready
	
	after ->
		stash.quit()
	
	it 'should store values', (done) ->
		stash.set 'foo', 42, (err) ->
			expect(err).to.not.exist
			done()
	
	it 'should retrieve previously-stored values', (done) ->
		stash.set 'foo', 42, (err) ->
			expect(err).to.not.exist
			stash.get 'foo', (err, result) ->
				expect(err).to.not.exist
				expect(result).to.eql(42)
				done()
	
	it 'should store packed objects', (done) ->
		obj = {foo: 'bar'}
		stash.set 'foo', obj, (err) ->
			expect(err).to.not.exist
			done()
	
	it 'should unpack objects on retrieval', (done) ->
		obj = {foo: 'bar'}
		stash.set 'foo', obj, (err) ->
			expect(err).to.not.exist
			stash.get 'foo', (err, result) ->
				expect(err).to.not.exist
				expect(result).to.eql(obj)
				done()
