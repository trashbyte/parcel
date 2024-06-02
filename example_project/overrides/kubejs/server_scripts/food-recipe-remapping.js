// priority: 0

onEvent('recipes', event => {
	for (let entry of global.data.replacements) {
		event.remove({type: "twilightforest:uncrafting", input: entry.target})
		event.remove({type: "twilightforest:uncrafting", output: entry.target})
		
		if (entry.inputReplace) {
			event.replaceInput({}, entry.target, entry.replace)
		}
		else {
			event.remove({input: entry.target})
		}

		if (entry.outputReplace) {
			event.replaceOutput({}, entry.target, entry.replace)
		}
		else {
			event.remove({output: entry.target})
		}
	}
})