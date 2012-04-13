# fountain-js 0.1.10
# http://www.opensource.org/licenses/mit-license.php
# Copyright (c) 2012 Matt Daly

'use strict'

regex =
	title_page: /^((?:title|credit|author[s]?|source|notes|draft date|date|contact|copyright)\:)/gim

	scene_heading: /^((?:\*{0,3}_?)?(?:(?:int|ext|est|i\/e)[. ]).+)|^(?:\.(?!\.+))(.+)/i
	scene_number: /( *#(.+)# *)/,

	transition: /^((?:FADE (?:TO BLACK|OUT)|CUT TO BLACK)\.|.+ TO\:)|^(?:> *)(.+)/
	
	dialogue: /^([A-Z*_]+[0-9A-Z (._\-')]*)(\^?)?(?:\n(?!\n+))([\s\S]+)/
	parenthetical: /^(\(.+\))$/

	action: /^(.+)/g,
	centered: /^(?:> *)(.+)(?: *<)(\n.+)*/g
		
	section: /^(#+)(?: *)(.*)/
	synopsis: /^(?:\=(?!\=+) *)(.*)/

	note: /^(?:\[{2}(?!\[+))(.+)(?:\]{2}(?!\[+))$/
	note_inline: /(?:\[{2}(?!\[+))([\s\S]+?)(?:\]{2}(?!\[+))/g
	boneyard: /(^\/\*|^\*\/)$/g

	page_break: /^\={3,}$/
	line_break: /^ {2}$/

	emphasis: /(_|\*{1,3}|_\*{1,3}|\*{1,3}_)(.+)(_|\*{1,3}|_\*{1,3}|\*{1,3}_)/g
	bold_italic_underline: /(_{1}\*{3}(?=.+\*{3}_{1})|\*{3}_{1}(?=.+_{1}\*{3}))(.+?)(\*{3}_{1}|_{1}\*{3})/g
	bold_underline: /(_{1}\*{2}(?=.+\*{2}_{1})|\*{2}_{1}(?=.+_{1}\*{2}))(.+?)(\*{2}_{1}|_{1}\*{2})/g
	italic_underline: /(?:_{1}\*{1}(?=.+\*{1}_{1})|\*{1}_{1}(?=.+_{1}\*{1}))(.+?)(\*{1}_{1}|_{1}\*{1})/g
	bold_italic: /(\*{3}(?=.+\*{3}))(.+?)(\*{3})/g
	bold: /(\*{2}(?=.+\*{2}))(.+?)(\*{2})/g
	italic: /(\*{1}(?=.+\*{1}))(.+?)(\*{1})/g
	underline: /(_{1}(?=.+_{1}))(.+?)(_{1})/g

	splitter: /\n{2,}/g
	cleaner: /^\n+|\n+$/
	standardizer: /\r\n|\r/g
	whitespacer: /^\t+|^ {3,}/gm


lexer = (script) ->
	script.replace(regex.boneyard, '\n$1\n')
		.replace(regex.standardizer, '\n')
		.replace(regex.cleaner, '')
		.replace(regex.whitespacer, '')


tokenize = (script) ->
	src = lexer(script).split(regex.splitter)
	i = src.length
	tokens = []

	while (i--)
		line = src[i]

		# title page
		if regex.title_page.test(line)
			match = line.replace(regex.title_page, '\n$1').split(regex.splitter).reverse()
			for x in [0 .. match.length - 1]
				parts = match[x].replace(regex.cleaner, '').split(/\:\n*/)
				tokens.push
					type: parts[0].trim().toLowerCase().replace(' ', '_')
					text: parts[1].trim()
			continue

		# scene headings
		if match = line.match(regex.scene_heading)
			text = match[1] || match[2]
			if text.indexOf('	') != text.length - 2
				if meta = text.match(regex.scene_number)
					meta = meta[2]
					text = text.replace(regex.scene_number, '')
				tokens.push
					type: 'scene_heading'
					text: text
					scene_number: meta || undefined
			continue

		# centered
		if match = line.match(regex.centered)
			tokens.push
				type: 'centered'
				text: match[0].replace(/>|</g, '')
			continue

		# transitions
		if match = line.match(regex.transition)
			tokens.push
				type: 'transition'
				text: match[1] || match[2]
			continue
	
		# dialogue blocks - characters, parentheticals and dialogue
		if match = line.match(regex.dialogue)
			if match[1].indexOf('	') != match[1].length - 2
				# we're iterating from the bottom up, so we need to push these backwards
				if match[2]
					tokens.push type: 'dual_dialogue_end'

				tokens.push type: 'dialogue_end'

				parts = match[3].split(/(\(.+\))(?:\n+)/).reverse()

				for x in [0 .. parts.length - 1]
					text = parts[x]
					if text.length > 0
						tokens.push
							type: if regex.parenthetical.test(text) then 'parenthetical' else 'dialogue'
							text: text

				tokens.push
					type: 'character'
					text: match[1].trim()
				tokens.push
					type: 'dialogue_begin'
					dual: if match[2] then 'right' else if dual then 'left' else undefined

				if dual
					tokens.push
						type: 'dual_dialogue_begin'

				dual = !!match[2]
				continue

		# section
		if match = line.match(regex.section)
			tokens.push
				type: 'section'
				text: match[2]
				depth: match[1].length
			continue
		
		# synopsis
		if match = line.match(regex.synopsis)
			tokens.push
				type: 'synopsis'
				text: match[1]
			continue

		# notes
		if match = line.match(regex.note)
			tokens.push
				type: 'note'
				text: match[1]
			continue

		# boneyard
		if match = line.match(regex.boneyard)
			tokens.push
				type: if match[0][0] == '/' then 'boneyard_begin' else 'boneyard_end'
			continue	

		# page breaks
		if regex.page_break.test(line)
			tokens.push type: 'page_break'
			continue
		
		# line breaks
		if regex.line_break.test(line)
			tokens.push type: 'line_break'
			continue

		tokens.push
			type: 'action'
			text: line
	tokens


inline =
	note: '<!-- $1 -->'

	line_break: '<br />'

	bold_italic_underline: '<span class="bold italic underline">$2</span>'
	bold_underline: '<span class="bold underline">$2</span>'
	italic_underline: '<span class="italic underline">$2</span>'
	bold_italic: '<span class="bold italic">$2</span>'
	bold: '<span class="bold">$2</span>'
	italic: '<span class="italic">$2</span>'
	underline: '<span class="underline">$2</span>'


inline.lexer = (s) ->
	return unless s
	styles = ['underline', 'italic', 'bold', 'bold_italic', 'italic_underline', 'bold_underline', 'bold_italic_underline']
	i = styles.length
	s = s.replace(regex.note_inline, inline.note).replace(/\\\*/g, '[star]').replace(/\\_/g, '[underline]').replace(/\n/g, inline.line_break);

	while i--
		style = styles[i]
		match = regex[style]
		if match.test(s)
			s = s.replace(match, inline[style])

	s.replace(/\[star\]/g, '*').replace(/\[underline\]/g, '_').trim()


fountain = (script, toks) ->
	tokens = tokenize(script)
	i = tokens.length
	title_page = []
	html = []

	while i--
		token = tokens[i]
		token.text = inline.lexer(token.text)

		switch token.type
			when 'title'
				title_page.push "<h1>#{token.text}</h1>"
				title = token.text.replace('<br />', ' ').replace(/<(?:.|\n)*?>/g, '')
			when 'credit'
				title_page.push "<p class='credit'>#{token.text}</p>"
			when 'author'
				title_page.push "<p class='authors'>#{token.text}</p>"
			when 'authors'
				title_page.push "<p class='authors'>#{token.text}</p>"
			when 'source'
				title_page.push "<p class='source'>#{token.text}</p>"
			when 'notes'
				title_page.push "<p class='notes'>#{token.text}</p>"
			when 'draft_date'
				title_page.push "<p class='draft-date'>#{token.text}</p>"
			when 'date'
				title_page.push "<p class='date'>#{token.text}</p>"
			when 'contact'
				title_page.push "<p class='contact'>#{token.text}</p>"
			when 'copyright'
				title_page.push "<p class='copyright'>#{token.text}</p>"

			when 'scene_heading'
				if token.scene_number
					html.push "<h3 id='#{token.scene_number}'>#{token.text}</h3>"
				else
					html.push "<h3>#{token.text}</h3>"
			when 'transition'
				html.push "<h2>#{token.text}</h2>"

			when 'dual_dialogue_begin'
				html.push "<div class='dual-dialogue'>"
			when 'dialogue_begin'
				if token.dual
					html.push "<div class='dialogue #{token.dual}'>"
				else
					html.push "<div class='dialogue'>"
			when 'character'
				html.push "<h4>#{token.text}</h4>"
			when 'parenthetical'
				html.push "<p class='parenthetical'>#{token.text}</p>"
			when 'dialogue'
				html.push "<p>#{token.text}</p>"
			when 'dialogue_end'
				html.push "</div> "
			when 'dual_dialogue_end'
				html.push "</div> "

			when 'section'
				html.push "<p class='section' data-depth='#{token.depth}'>#{token.text}</p>"
			when 'synopsis'
				html.push "<p class='synopsis'>#{token.text}</p>"

			when 'note'
				html.push "<!-- #{token.text} -->"
			when 'boneyard_begin'
				html.push "<!-- "
			when 'boneyard_end'
				html.push " -->"

			when 'action'
				html.push "<p>#{token.text}</p>"
			when 'centered'
				html.push "<p class='centered'>#{token.text}</p>"
			
			when 'page_break'
				html.push "<hr />"
			when 'line_break'
				html.push "<br />"

	output =
		title: title
		html:
			title_page: title_page.join('')
			script: html.join('')
		tokens: if toks then tokens.reverse() else undefined
	output

if typeof module != 'undefined'
	module.exports = fountain

