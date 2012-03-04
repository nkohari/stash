async  = require 'async'
expect = require('chai').expect
Stash  = require '../src/Stash'

describe 'Given a scenario with no dependencies', ->
	stash = new Stash()
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set 'comment1', comment1, done
			(done) -> stash.set 'comment2', comment2, done
		], ready

	afterEach (ready) ->
		keys = ['comment1', 'comment2']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should delete only the invalidated entry', (done) ->
		stash.inv 'comment1', (err, invalid) ->
			expect(err).to.not.exist
			expect(invalid).to.be.eql ['comment1']
			done()

describe 'Given a scenario with one dependency', ->
	stash = new Stash()

	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	post1    = {author: 'joe', text: 'blah', comments: [comment1, comment2]}
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set 'comment1', comment1, done
			(done) -> stash.set 'comment2', comment2, done
			(done) -> stash.set 'post1',    post1, done
			(done) -> stash.dep 'post1',    ['comment1', 'comment2'], done
		], ready
	
	afterEach (ready) ->
		keys = ['comment1', 'comment2', 'post1']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should invalidate the parent when the child is invalidated', (done) ->
		stash.inv 'comment1', (err, invalid) ->
			expect(err).to.not.exist
			expect(invalid).to.be.eql ['comment1', 'post1']
			done()

describe 'Given a scenario with a circular dependency', ->
	stash = new Stash()

	obj1 = {text: 'foo'}
	obj2 = {text: 'bar'}
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set 'obj1', obj1, done
			(done) -> stash.dep 'obj1', 'obj2', done
			(done) -> stash.set 'obj2', obj2, done
			(done) -> stash.dep 'obj2', 'obj1', done
		], ready
	
	afterEach (ready) ->
		keys = ['obj1', 'obj2']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should invalidate both entries without imploding the universe', (done) ->
		stash.inv 'obj1', (err, invalid) ->
			expect(err).to.not.exist
			expect(invalid).to.be.eql ['obj1', 'obj2']
			done()

describe 'Given a scenario with two levels of dependencies', ->
	stash = new Stash()
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	comment3 = {author: 'bob',  text: 'bloo'}
	post1    = {author: 'joe', text: 'blah', comments: [comment1, comment2]}
	post2    = {author: 'joe', text: 'derp', comments: [comment3]}
	page1    = [post1, post2]
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set 'comment1', comment1, done
			(done) -> stash.set 'comment2', comment2, done
			(done) -> stash.set 'post1', post1, done
			(done) -> stash.dep 'post1', ['comment1', 'comment2'], done
			(done) -> stash.set 'post2', post2, done
			(done) -> stash.dep 'post2', 'comment3', done
			(done) -> stash.set 'page1', page1, done
			(done) -> stash.dep 'page1', ['post1', 'post2'], done
		], ready

	afterEach (ready) ->
		keys = ['comment1', 'comment2', 'comment3', 'post1', 'post2', 'page1']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should invalidate all dependencies', (done) ->
		stash.inv 'comment1', (err, invalid) ->
			expect(err).to.not.exist
			expect(invalid).to.be.eql ['comment1', 'post1', 'page1']
			done()
