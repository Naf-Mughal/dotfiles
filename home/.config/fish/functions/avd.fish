function avd --description 'Android emulator window: avd [name] (default pixel-api35); avd list'
    if test "$argv[1]" = list
        emulator -list-avds
        return
    end
    set -l name pixel-api35
    test (count $argv) -gt 0; and set name $argv[1]
    # window with the side toolbar, KVM + host GPU; detached so the terminal stays free
    nohup emulator -avd $name -gpu host -memory 4096 -cores 4 -scale 0.35 >/dev/null 2>&1 &
    disown
    echo "starting $name (adb devices to check)"
end
