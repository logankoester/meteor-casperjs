TEST_FRAMEWORK_NAME = "casperjs"

if process.env.NODE_ENV is "development"
	if Velocity and Velocity.registerTestingFramework
		Velocity.registerTestingFramework TEST_FRAMEWORK_NAME,
			regex: "#{TEST_FRAMEWORK_NAME}/.+\\.(js|coffee|litcoffee|coffee\\.md)$"
			sampleTestGenerator: ->
				[
					{
						path: "#{TEST_FRAMEWORK_NAME}/sampleTest.coffee"
						contents: Assets.getText "sample-tests/sampleTest.coffee"
					}
				]

	spawn = (Npm.require 'child_process').spawn
	glob = Npm.require 'glob'
	fs = Npm.require 'fs'
	pathnpm = Npm.require 'path'
	parseString = (Npm.require 'xml2js').parseString
	Future = Npm.require 'fibers/future'

	Meteor.startup ->
		# if process.env.IS_MIRROR
		resetReports()

		(VelocityTestFiles.find targetFramework: TEST_FRAMEWORK_NAME).observe
			added: runTestFile
			changed: runTestFile
			removed: removeReportForTestFile

	resetReports = ->
		Meteor.call 'resetReports', framework: TEST_FRAMEWORK_NAME

		path = "#{Velocity.getTestsPath()}/.reports/#{TEST_FRAMEWORK_NAME}"
		files = glob.sync "**/*.xml", cwd: path
		fs.unlink "#{path}/#{file}" for file in files

	getReportFilePath = (file) ->
		"#{Velocity.getTestsPath()}/.reports/#{TEST_FRAMEWORK_NAME}/#{pathnpm.basename(file.absolutePath)}.xml"

	runTestFile = (file) ->
		future = new Future

		# Only run tests for .js or .coffee files
		return unless pathnpm.extname(file.absolutePath) in [".js", ".coffee"]

		console.log "Run tests for file #{file.absolutePath}..."

		reportFile = getReportFilePath file
		child = spawn 'casperjs', ['test', "--xunit=#{reportFile}", file.absolutePath]
		# child.stdout.on 'data', (msg) -> process.stdout.write msg
		# child.stderr.on 'data', (msg) -> process.stderr.write msg
		child.on 'exit', (code) ->
			process.stderr.write "Casperjs exited with code #{code}" if code > 0
			future.return()

		future.wait()
		# Velocity.parseXmlFiles TEST_FRAMEWORK_NAME
		parseReport reportFile

	removeReportForTestFile = (file) ->
		reportFile = getReportFilePath file
		fs.unlink reportFile if fs.existsSync reportFile

	parseReport = (path) ->
		hashCode = (s) ->
			(s.split "").reduce (a, b) ->
				a = ((a << 5) - a) + b.charCodeAt 0
				a & a
			, 0

		parseString (fs.readFileSync path), (err, result) ->
			for testsuite in result.testsuites.testsuite
				for testcase in testsuite.testcase
					result =
						name: testcase.$.name
						framework: TEST_FRAMEWORK_NAME
						result: if testcase.failure then 'failed' else 'passed'
						timestamp: testsuite.$.timestamp
						time: testcase.$.time
						ancestors: [testcase.$.classname]

					if testcase.failure
						for failure in testcase.failure
							result.failureType = failure.$.type
							result.failureMessage = failure.$.message
							result.failureStackTrace = failure._

					result.id = "#{TEST_FRAMEWORK_NAME}:#{hashCode(pathnpm.basename(path) + testcase.$.classname + testcase.$.name)}"
					Meteor.call 'postResult', result
