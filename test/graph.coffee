async  = require 'async'
expect = require('chai').expect
Stash  = require '../src/Stash'

describe 'Given a scenario with no dependencies', ->
	stash = new Stash()
	allkeys = ['comment1', 'comment2']
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set 'comment1', comment1, done
			(done) -> stash.set 'comment2', comment2, done
		], ready

	afterEach (ready) ->
		stash.rem allkeys, ready
	
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
	allkeys = ['comment1', 'comment2', 'post1']

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
		stash.rem allkeys, ready
	
	after ->
		stash.quit()
	
	it 'should correctly add dependency links', (done) ->
		stash.dget ['comment1', 'post1'], (err, deps) ->
			expect(err).to.not.exist
			expect(deps['comment1'].in).to.be.empty
			expect(deps['comment1'].out).to.be.eql ['post1']
			expect(deps['post1'].in).to.be.eql ['comment1', 'comment2']
			expect(deps['post1'].out).to.be.eql []
			done()
	
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
	allkeys = ['obj1', 'obj2']

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
		stash.rem allkeys, ready
	
	after ->
		stash.quit()
	
	it 'should create dependency links', (done) ->
		stash.dget ['obj1', 'obj2'], (err, deps) ->
			expect(err).to.not.exist
			expect(deps['obj1'].in).to.eql ['obj2']
			expect(deps['obj1'].out).to.eql ['obj2']
			expect(deps['obj2'].in).to.eql ['obj1']
			expect(deps['obj2'].out).to.eql ['obj1']
			done()

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
	allkeys = ['comment1', 'comment2', 'comment3', 'post1', 'post2', 'page1']
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	comment3 = {author: 'bob',  text: 'bloo'}
	post1    = {author: 'joe', text: 'blah', comments: [comment1, comment2]}
	post2    = {author: 'joe', text: 'derp', comments: [comment3]}
	page1    = [post1, post2]
	
	beforeEach (ready) ->
		async.parallel [
			(done) -> stash.set  'comment1', comment1, done
			(done) -> stash.set  'comment2', comment2, done
			(done) -> stash.set  'comment3', comment3, done
			(done) -> stash.set  'post1', post1, done
			(done) -> stash.dadd 'post1', ['comment1', 'comment2'], done
			(done) -> stash.set  'post2', post2, done
			(done) -> stash.dadd 'post2', 'comment3', done
			(done) -> stash.set  'page1', page1, done
			(done) -> stash.dadd 'page1', ['post1', 'post2'], done
		], ready

	afterEach (ready) ->
		stash.rem allkeys, ready
	
	after ->
		stash.quit()
	
	it 'should create dependency links', (done) ->
		stash.dget allkeys, (err, deps) ->
			expect(err).to.not.exist
			expect(deps['comment1'].in).to.empty
			expect(deps['comment1'].out).to.eql ['post1']
			expect(deps['comment2'].in).to.empty
			expect(deps['comment2'].out).to.eql ['post1']
			expect(deps['comment3'].in).to.empty
			expect(deps['comment3'].out).to.eql ['post2']
			expect(deps['post1'].in).to.eql ['comment1', 'comment2']
			expect(deps['post1'].out).to.eql ['page1']
			expect(deps['post2'].in).to.eql ['comment3']
			expect(deps['post2'].out).to.eql ['page1']
			expect(deps['page1'].in).to.eql ['post1', 'post2']
			expect(deps['page1'].out).to.be.empty
			done()
		
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
				stash.dget ['post1', 'post2'], (err, deps) ->
					expect(err).to.not.exist
					expect(deps['post1'].in).to.eql ['comment1', 'comment2']
					expect(deps['post2'].in).to.eql ['comment3']
					done()

	describe 'When inv() is called', ->
		it 'should invalidate all dependencies when child is invalidated', (done) ->
			stash.inv 'comment1', (err, invalid) ->
				expect(err).to.not.exist
				expect(invalid).to.be.eql ['comment1', 'post1', 'page1']
				done()
