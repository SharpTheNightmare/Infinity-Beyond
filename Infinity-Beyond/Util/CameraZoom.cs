using System.Reflection;
using UnityEngine;
using MelonLoader;

namespace Infinity_TestMod.Util
{
    // Scales the active CameraFollow's orthographic size by a multiplier.
    // We capture the game's original size the first time we touch a given
    // CameraFollow instance so Reset (and area changes that swap the camera)
    // restore correctly. camHalfHeight/Width are kept in sync because the
    // game's LateUpdate uses them to clamp the camera inside the area's
    // BoxCollider confiner — stale half-extents would let the camera drift
    // past the room edge after zooming out.
    //
    // CameraFollow.cam, camHalfHeight, and camHalfWidth are all private,
    // so this is all reflection. Field handles are cached after the first
    // lookup.
    public static class CameraZoom
    {
        public const float Min = 0.5f;
        public const float Max = 3.0f;
        public const float Default = 1.0f;

        public static float Multiplier = Default;

        private static readonly FieldInfo _fCam = typeof(CameraFollow).GetField("cam", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo _fHalfH = typeof(CameraFollow).GetField("camHalfHeight", BindingFlags.Instance | BindingFlags.NonPublic);
        private static readonly FieldInfo _fHalfW = typeof(CameraFollow).GetField("camHalfWidth", BindingFlags.Instance | BindingFlags.NonPublic);

        private static CameraFollow _trackedFollow;
        private static float _originalOrthoSize;
        private static float _originalFov;
        private static bool _captured;

        public static void Apply()
        {
            try
            {
                var follow = Object.FindObjectOfType<CameraFollow>();
                if (follow == null) return;
                var cam = _fCam?.GetValue(follow) as Camera;
                if (cam == null) return;

                if (follow != _trackedFollow)
                {
                    _trackedFollow = follow;
                    _originalOrthoSize = cam.orthographicSize;
                    _originalFov = cam.fieldOfView;
                    _captured = true;
                }

                if (!_captured) return;

                float m = Mathf.Clamp(Multiplier, Min, Max);
                if (cam.orthographic)
                {
                    float size = _originalOrthoSize * m;
                    cam.orthographicSize = size;
                    _fHalfH?.SetValue(follow, size);
                    _fHalfW?.SetValue(follow, size * cam.aspect);
                }
                else
                {
                    cam.fieldOfView = Mathf.Clamp(_originalFov * m, 1f, 179f);
                }
            }
            catch (System.Exception ex)
            {
                MelonLogger.Error($"[CameraZoom] Apply failed: {ex.Message}");
            }
        }

        public static void Reset()
        {
            Multiplier = Default;
            Apply();
        }
    }
}
