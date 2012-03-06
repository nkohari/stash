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
	
	it 'should not create dependency links', (done) ->
		stash.dget 'comment1', (err, deps) ->
			expect(err).to.not.exist
			expect(deps.in).to.be.empty
			expect(deps.out).to.be.empty
			done()
	
	describe 'When inv() is called', ->
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
			(done) -> stash.set  'comment1', comment1, done
			(done) -> stash.set  'comment2', comment2, done
			(done) -> stash.set  'post1',    post1, done
			(done) -> stash.dadd 'post1',    ['comment1', 'comment2'], done
		], ready
	
	afterEach (ready) ->
		keys = ['comment1', 'comment2', 'post1']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should correctly add dependency links', (done) ->
		tests = []
		tests.push (next) ->
			stash.dget 'comment1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.empty
				expect(deps.out).to.be.eql ['post1']
				next()
		tests.push (next) ->
			stash.dget 'post1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.eql ['comment1', 'comment2']
				expect(deps.out).to.be.eql []
				next()
		async.parallel tests, done
	
	describe 'When dset() is called', ->
		it 'should replace the dependency links', (done) ->
			stash.dset 'post1', ['comment1'], (err, result) ->
				expect(err).to.not.exist
				expect(result.added).to.be.empty
				expect(result.removed).to.eql ['comment2']
				done()
	
	describe 'When drem() is called with no arguments', ->
		it 'should remove all dependency links', (done) ->
			stash.drem 'post1', (err, removed) ->
				expect(err).to.not.exist
				expect(removed).to.be.eql ['comment1', 'comment2']
				done()
	
	describe 'When drem() is called with arguments', ->
		it 'should remove the dependency links to the specified items', (done) ->
			stash.drem 'post1', 'comment1', (err, removed) ->
				expect(err).to.not.exist
				expect(removed).to.eql ['comment1']
				stash.dget 'post1', (err, deps) ->
					expect(err).to.not.exist
					expect(deps.in).to.eql ['comment2']
					done()
	
	describe 'When inv() is called', ->
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
			(done) -> stash.set  'obj1', obj1, done
			(done) -> stash.dadd 'obj1', 'obj2', done
			(done) -> stash.set  'obj2', obj2, done
			(done) -> stash.dadd 'obj2', 'obj1', done
		], ready
	
	afterEach (ready) ->
		keys = ['obj1', 'obj2']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should create dependency links', (done) ->
		tests = []
		tests.push (next) ->
			stash.dget 'obj1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.eql ['obj2']
				expect(deps.out).to.be.eql ['obj2']
				next()
		tests.push (next) ->
			stash.dget 'obj2', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.eql ['obj1']
				expect(deps.out).to.be.eql ['obj1']
				next()
		async.parallel tests, done

	describe 'When drem() is called', ->
		it 'should remove one side of the dependency links', (done) ->
			stash.drem 'obj1', (err, removed) ->
				expect(err).to.not.exist
				expect(removed).to.eql ['obj2']
				stash.dget 'obj2', (err, deps) ->
					expect(err).to.not.exist
					expect(deps.in).to.eql ['obj1']
					done()
	
	describe 'When inv() is called', ->
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
			(done) -> stash.set  'comment2', comment2, done
			(done) -> stash.set  'post1', post1, done
			(done) -> stash.dadd 'post1', ['comment1', 'comment2'], done
			(done) -> stash.set  'post2', post2, done
			(done) -> stash.dadd 'post2', 'comment3', done
			(done) -> stash.set  'page1', page1, done
			(done) -> stash.dadd 'page1', ['post1', 'post2'], done
		], ready

	afterEach (ready) ->
		keys = ['comment1', 'comment2', 'comment3', 'post1', 'post2', 'page1']
		stash.rem keys, ready
	
	after ->
		stash.quit()
	
	it 'should create dependency links', (done) ->
		tests = []
		tests.push (next) ->
			stash.dget 'comment1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.empty
				expect(deps.out).to.be.eql ['post1']
				next()
		tests.push (next) ->
			stash.dget 'post1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.eql ['comment1', 'comment2']
				expect(deps.out).to.be.eql ['page1']
				next()
		tests.push (next) ->
			stash.dget 'page1', (err, deps) ->
				expect(err).to.not.exist
				expect(deps.in).to.be.eql ['post1', 'post2']
				expect(deps.out).to.be.empty
				next()
		async.parallel tests, done
		
	describe 'When drem() is called at the first level of items', ->
		it 'should remove the first level of dependency links without affecting the second level', (done) ->
			stash.drem 'post1', (err, removed) ->
				expect(err).to.not.exist
				expect(removed).to.eql ['comment1', 'comment2']
				stash.dget 'page1', (err, deps) ->
					expect(err).to.not.exist
					expect(deps.in).to.eql ['post1', 'post2']
					done()

	describe 'When drem() is called at the second level of items', ->
		it 'should remove the second level of dependency links without affecting the first level', (done) ->
			stash.drem 'page1', (err, removed) ->
				expect(err).to.not.exist
				expect(removed).to.eql ['post1', 'post2']
				funcs = []
				funcs.push (next) ->
					stash.dget 'post1', (err, deps) ->
						expect(err).to.not.exist
						expect(deps.in).to.eql ['comment1', 'comment2']
						next()
				funcs.push (next) ->
					stash.dget 'post2', (err, deps) ->
						expect(err).to.not.exist
						expect(deps.in).to.eql ['comment3']
						next()
				async.parallel funcs, done

	describe 'When inv() is called', ->
		it 'should invalidate all dependencies when child is invalidated', (done) ->
			stash.inv 'comment1', (err, invalid) ->
				expect(err).to.not.exist
				expect(invalid).to.be.eql ['comment1', 'post1', 'page1']
				done()
