class_name CameraAccess
extends RefCounted

## Reach the cameras on every platform.
##
## Godot 4.6 implements no camera on Windows, so we load CameraServerExtension
## there (see addons/CameraServerExtension/CameraServerExtension.gdextension).
## The formats of its feeds are reached only by name: the methods of CameraFeed
## called through a typed reference end up in the base class, which lists no
## formats. Hence we always call get_formats and set_format by name.

## The extension must live as long as its feeds are in use, i.e., for the whole
## game, so we keep it here and not in a scene.
static var _extension: Object = null

## Why there is no camera even if the feeds might be there, or "" if we do not
## know of any such reason.
static var problem: String = ""


## Start monitoring the camera feeds, and load the extension on Windows.
##
## The extension must be created after the feeds are monitored.
static func start() -> void:
    CameraServer.monitoring_feeds = true
    if OS.get_name() == "Windows":
        _start_extension()


static func _start_extension() -> void:
    # NOTE (mristin):
    # The packaging puts the extension next to the executable; in the editor,
    # it stays in the project.
    var directory: String
    if OS.has_feature("editor"):
        directory = ProjectSettings.globalize_path("res://addons/CameraServerExtension")
    else:
        directory = OS.get_executable_path().get_base_dir()

    var path := directory.path_join("CameraServerExtension.gdextension")
    if not FileAccess.file_exists(path):
        push_warning("The camera extension %s is missing; there is no camera on Windows without it." % path)
        problem = (
            "The camera extension (CameraServerExtension.gdextension) is missing " +
            "next to the game. Please unpack the whole package again."
        )
        return

    var status := GDExtensionManager.load_extension(path)
    if (
        status != GDExtensionManager.LOAD_STATUS_OK
        and status != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED
    ):
        push_warning("The camera extension %s did not load: %s." % [path, status])
        problem = "The camera extension could not be loaded."
        return

    if not ClassDB.class_exists("CameraServerExtension"):
        push_warning("The camera extension %s loaded, but provides no CameraServerExtension." % path)
        problem = "The camera extension could not be loaded."
        return

    _extension = ClassDB.instantiate("CameraServerExtension")
    print("Loaded the camera extension ", path, ".")

    if _extension != null and not _extension.call("permission_granted"):
        problem = (
            "Windows does not allow the game to use the camera. Please allow " +
            "the apps to access the camera in the privacy settings of Windows."
        )


## List the formats of the feed; empty if the platform does not list them
## (e.g., macOS), in which case the feed runs in its default format.
static func get_formats(feed: CameraFeed) -> Array:
    return feed.call("get_formats")


## Set the format of the feed by its index in get_formats.
static func set_format(feed: CameraFeed, format_index: int) -> bool:
    return feed.call("set_format", format_index, {})
