# Kitten allowing for remote-controlling window-switching from NeoVIM.
#
# Used for mapping ctrl+hjkl to navigating seamlessly between NeoVIM windows
# and Kitty windows.

from kittens.tui.handler import result_handler

def main():
    pass

@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    boss.active_tab.neighboring_window(args[1])
