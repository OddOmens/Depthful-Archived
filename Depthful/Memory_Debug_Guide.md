# Depthful Memory Issues - Debug & Fix Guide

## Immediate Actions to Take

### 1. Enable Memory Debugging in Xcode
1. **Product** → **Scheme** → **Edit Scheme**
2. **Run** → **Diagnostics** tab
3. Enable:
   - ✅ **Memory Management** → **Malloc Stack Logging**
   - ✅ **Memory Management** → **Malloc Scribble** 
   - ✅ **Memory Management** → **Guard Malloc**
   - ✅ **Runtime Issues** → **Main Thread Checker**

### 2. Use Instruments for Memory Profiling
```bash
# Run with Leaks instrument
Product → Profile (⌘+I) → Choose "Leaks" template
```

## Most Likely Causes in Your App

### 1. **Image Memory Issues** (Most Common)
**Problem**: Loading full-resolution images without proper memory management

**Check these files**: `ContentView.swift`, any image display components

**Symptoms**:
- Memory spikes when viewing photos
- Crashes when scrolling through images
- Multiple images loaded simultaneously

### 2. **Core Data Memory Leaks**
**Problem**: Not properly managing Core Data contexts and objects

**Check**: All Core Data fetch requests and object relationships

### 3. **Audio File Memory**
**Problem**: Keeping large audio files in memory instead of streaming

**Check**: Audio playback and recording components

### 4. **Localization/Translation Memory**
**Problem**: Loading all language strings at once (unlikely but possible)

## Quick Fixes to Try First

### Fix 1: Image Memory Management
Add this to image loading components:

```swift
// In your image views, ensure proper memory management
Image(uiImage: image)
    .resizable()
    .aspectRatio(contentMode: .fit)
    .frame(maxWidth: 300, maxHeight: 300) // Limit size
    .clipped()
    .onDisappear {
        // Clear image from memory when not visible
    }
```

### Fix 2: Core Data Context Management
```swift
// Ensure you're not retaining Core Data objects unnecessarily
viewContext.refresh(object, mergeChanges: false)
```

### Fix 3: Limit Concurrent Operations
```swift
// Limit the number of images/audio files processed at once
private let operationQueue = OperationQueue()
operationQueue.maxConcurrentOperationCount = 3
```

## Memory Monitoring Code

Add this to your main view to monitor memory usage:

```swift
// Add to ContentView.swift for debugging
#if DEBUG
import os.log

private func logMemoryUsage() {
    let memoryUsage = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryUsage) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let memoryMB = Double(memoryUsage.resident_size) / 1024 / 1024
        print("Memory usage: \(String(format: "%.2f", memoryMB)) MB")
    }
}
#endif
```

## Specific Areas to Check

### 1. Image Gallery/Photo Handling
- Are you loading full-resolution images?
- Do you have image caching without size limits?
- Are thumbnails being generated efficiently?

### 2. Audio Recording/Playback
- Are audio files being kept in memory after playback?
- Is audio data being duplicated?

### 3. Core Data Fetches
- Are you fetching too many objects at once?
- Do you have proper batch sizes set?
- Are relationships being faulted properly?

### 4. View Management
- Are views being properly deallocated?
- Do you have retain cycles in closures?

## Testing Steps

1. **Start with minimal data** - Test with 1-2 thoughts
2. **Add images gradually** - See when memory spikes
3. **Test audio separately** - Isolate audio memory usage
4. **Monitor during scrolling** - Check if views are released
5. **Test language switching** - Ensure translations don't accumulate

## Emergency Temporary Fixes

If you need immediate relief:

1. **Reduce image quality**:
   ```swift
   let compressedData = image.jpegData(compressionQuality: 0.5)
   ```

2. **Limit displayed content**:
   ```swift
   // Show only recent thoughts
   .fetchLimit(50)
   ```

3. **Clear caches periodically**:
   ```swift
   viewContext.refreshAllObjects()
   ```

## Next Steps After This Guide

1. Run Instruments Leaks tool
2. Check the specific areas mentioned above
3. Implement the monitoring code
4. Test incrementally with different data sizes
5. Profile again to confirm fixes 