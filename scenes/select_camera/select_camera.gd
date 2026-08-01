extends Control

@onready var status: Label = $Status

var compatible_feeds: Array[FeedRecord] = []

class FeedRecord:
    var feed: CameraFeed
    var format_index: int

    func _init(camera_feed: CameraFeed, fmt_index: int):
        feed = camera_feed
        format_index = fmt_index

signal any_key_pressed
func _input(event):
    if event is InputEventKey and event.pressed and not event.echo:
        any_key_pressed.emit()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    CameraServer.monitoring_feeds = true;
    await get_tree().create_timer(2.0).timeout
    
    
    print(
        "We have waited long enough for the camera server to start. " + 
        "Now let's see how many camera feeds we have."
    )
    
    if CameraServer.get_feed_count() == 0:
        status.text = (
            "Unfortunately, there are no camera feeds. Please attach your camera " + 
            "and start the game again.\n\nPress any key to quit."
        )
        await any_key_pressed
        get_tree().quit()
    
    $SelectionPart.visible = true;

    var camera_option: OptionButton = $SelectionPart/CameraOption
    compatible_feeds.clear()

    # Filter feeds to only include those with 640x480 YUYV format
    for i in range(CameraServer.get_feed_count()):
        var feed = CameraServer.get_feed(i)
        var formats = feed.get_formats()

        for format_idx in range(formats.size()):
            var format = formats[format_idx] as Dictionary
            var width = format.get("width", 0) as int
            var height = format.get("height", 0) as int
            var pixel_format = format.get("format", "") as String

            if width == 640 and height == 480 and pixel_format.begins_with("YUYV"):
                print("Found compatible feed: ", feed.get_name(), " with format: ", format)
                var feed_record = FeedRecord.new(feed, format_idx)
                compatible_feeds.append(feed_record)
                break

    # Handle different scenarios based on number of compatible feeds
    if compatible_feeds.is_empty():
        status.text = (
            "Unfortunately, we need the camera feed to support 640x480 YUYV format, " +
            "but none of them support it.\n\nPress any key to quit."
        )
        await any_key_pressed
        get_tree().quit()
        return

    elif compatible_feeds.size() == 1:
        # Auto-select the single compatible feed
        var feed_record = compatible_feeds[0]
        print("Auto-selecting single compatible feed: ", feed_record.feed.get_name())
        start(feed_record.feed, feed_record.format_index)
        return

    else:
        # Multiple feeds available - populate the option button
        status.text = "Please select the camera feed:"

        for feed_record in compatible_feeds:
            camera_option.add_item(feed_record.feed.get_name())

func _on_start_button_pressed() -> void:
    var camera_option: OptionButton = $SelectionPart/CameraOption
    var selected_index = camera_option.get_selected_id()

    if selected_index >= 0 and selected_index < compatible_feeds.size():
        var feed_record = compatible_feeds[selected_index]
        print("Starting with selected feed: ", feed_record.feed.get_name())
        start(feed_record.feed, feed_record.format_index)

func start(feed: CameraFeed, format_index: int) -> void:
    print("Setting feed format and activating feed: ", feed.get_name())
    feed.set_format(format_index, {})
    feed.feed_is_active = true

    var ergo_meter: ErgoMeter = load(
        "res://scenes/ergo_meter/ergo_meter.tscn"
    ).instantiate()
    ergo_meter.set_camera_feed(feed)

    var game: Game = load("res://scenes/game/game.tscn").instantiate()
    game.own_game_controllers([ergo_meter])

    get_tree().root.add_child(game)
    queue_free()
