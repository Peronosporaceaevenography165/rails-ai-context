# VHS demo — install: https://github.com/charmbracelet/vhs
# Run: vhs demo.tape

Output demo.gif

Set FontSize 16
Set Width 900
Set Height 500
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms

Type "bundle add rails-ai-context"
Enter
Sleep 2s

Type "rails ai:doctor"
Enter
Sleep 3s

Type "rails ai:context"
Enter
Sleep 3s

Type "# Your AI assistants now understand your entire Rails app."
Enter
Sleep 2s
