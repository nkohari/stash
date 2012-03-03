expect = require('chai').expect
Stash  = require '../src/Stash'

describe 'When no dependencies exist', ->
	stash = new Stash()
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	
	beforeEach ->
		stash.set 'comment:1', comment1
		stash.set 'comment:2', comment2

	afterEach ->
		stash.rem 'comment:1', 'comment:2'
	
	it 'should delete only the invalidated entry', (done) ->
		stash.inv 'comment:1', (err, invalid) ->
			expect(invalid).to.be.eql ['comment:1']
			done()

describe 'When a single dependency exists', ->
	stash = new Stash()

	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	post1    = {author: 'joe', text: 'blah', comments: [comment1, comment2]}
	
	beforeEach ->
		stash.set 'comment:1', comment1
		stash.set 'comment:2', comment2
		stash.set 'post:1',    post1
		stash.dep 'post:1',    ['comment:1', 'comment:2']
	
	afterEach ->
		stash.rem 'comment:1', 'comment:2', 'post:1'
	
	it 'should invalidate the dependency', (done) ->
		stash.inv 'comment:1', (err, invalid) ->
			expect(invalid).to.be.eql ['comment:1', 'post:1']
			done()

describe 'When a circular dependency exists', ->
	stash = new Stash()

	obj1 = {text: 'foo'}
	obj2 = {text: 'bar'}
	
	beforeEach ->
		stash.set 'obj:1', obj1
		stash.dep 'obj:1', 'obj:2'
		stash.set 'obj:2', obj2
		stash.dep 'obj:2', 'obj:1'
	
	afterEach ->
		stash.rem 'obj:1', 'obj:2'
	
	it 'should invalidate both keys without imploding the universe', (done) ->
		stash.inv 'obj:1', (err, invalid) ->
			expect(invalid).to.be.eql ['obj:1', 'obj:2']
			done()

describe 'When two levels of dependencies exist', ->
	stash = new Stash()
	
	comment1 = {author: 'jack', text: 'foo'}
	comment2 = {author: 'jill', text: 'bar'}
	comment3 = {author: 'bob',  text: 'bloo'}
	post1    = {author: 'joe', text: 'blah', comments: [comment1, comment2]}
	post2    = {author: 'joe', text: 'derp', comments: [comment3]}
	page1    = [post1, post2]
	
	beforeEach ->
		stash.set 'comment:1', comment1
		stash.set 'comment:2', comment2
		stash.set 'post:1',    post1
		stash.dep 'post:1',    ['comment:1', 'comment:2']
		stash.set 'post:2',    post2
		stash.dep 'post:2',    'comment:3'
		stash.set 'page:1',    page1
		stash.dep 'page:1',    ['post:1', 'post:2']
	
	afterEach ->
		stash.rem [
			'comment:1'
			'comment:2'
			'comment:3'
			'post:1'
			'post:2'
			'page:1'
		]
	
	it 'should invalidate all dependencies', (done) ->
		stash.inv 'comment:1', (err, invalid) ->
			expect(invalid).to.be.eql ['comment:1', 'post:1', 'page:1']
			done()
