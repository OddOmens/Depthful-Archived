import CoreData
import UIKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    // Track the current store version
    private let currentStoreVersion = 5

    var container: NSPersistentCloudKitContainer
    
    // Add a property to track persistence loading state
    var persistenceLoadError: Error?
    var isStoreLoaded = false

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Depthful")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Set up container for app group access to share with widget
            if let storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.oddOmens.depthful")?.appendingPathComponent("Depthful.sqlite") {
                let description = container.persistentStoreDescriptions.first
                description?.url = storeURL
                print("Using shared app group store URL: \(storeURL)")
            }
        }
        
        // Configure CloudKit integration
        guard let description = container.persistentStoreDescriptions.first else {
            let error = NSError(domain: "com.oddOmens.depthful", code: 1001, 
                                userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve a persistent store description."])
            self.persistenceLoadError = error
            print("Critical error: \(error.localizedDescription)")
            return
        }
        
        // Set up migration options
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // Enable automatic migration
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        
        // Set up CloudKit container
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.OddOmens.Depthful"
        )
        
        // Load persistent stores
        var controller = self
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Persistent store loading error: \(error), \(error.userInfo)")
                
                // Store the error but don't crash
                controller.persistenceLoadError = error
                
                // Attempt recovery based on error type
                if controller.attemptStoreRecovery(with: error) {
                    print("Successfully recovered from persistence error")
                } else {
                    print("Could not recover from persistence error. App will run in limited functionality mode.")
                }
            } else {
                print("Successfully loaded persistent store: \(storeDescription)")
                
                // Mark as successfully loaded
                controller.isStoreLoaded = true
                
                // Check store version after loading
                controller.checkStoreVersion()
            }
        })
        
        #if DEBUG
        do {
            if !inMemory {
                try container.initializeCloudKitSchema(options: [])
            }
        } catch {
            print("Error initializing CloudKit schema: \(error)")
        }
        #endif
        
        // Configure view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Set up remote change handling
        setupRemoteChangeHandling()
        
        // Set up background save handling
        setupBackgroundSaveHandling()
    }
    
    /// Attempts to recover from a persistent store error
    private func attemptStoreRecovery(with error: NSError) -> Bool {
        // 1. Check for common error scenarios
        if error.domain == NSCocoaErrorDomain {
            // Handle migration errors - use error code numbers directly
            if error.code == 134100 ||  // NSPersistentStoreIncompatibleVersionHashError
               error.code == 134110 ||  // NSMigrationMissingSourceModelError
               error.code == 134120 {   // NSMigrationError
                return migrateStore()
            }
            
            // Handle corrupted store
            if error.code == 134060 { // Core Data error
                return resetStore()
            }
        }
        
        // Try a generic recovery as last resort
        return resetStore()
    }
    
    /// Attempts to migrate a store with incompatible version
    private func migrateStore() -> Bool {
        // Get URL for the persistent store
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            // Create a backup of the database
            let backupURL = storeURL.deletingLastPathComponent().appendingPathComponent("Depthful-backup-\(Date().timeIntervalSince1970).sqlite")
            try FileManager.default.copyItem(at: storeURL, to: backupURL)
            print("Created backup at: \(backupURL)")
            
            // Limit the number of backups kept
            cleanupOldBackups(currentBackup: backupURL)
            
            // Reset the coordinator and try recreating the store
            return resetStore()
        } catch {
            print("Failed to create backup during recovery: \(error)")
            return false
        }
    }
    
    /// Cleans up old backups, keeping only the most recent ones
    private func cleanupOldBackups(currentBackup: URL) {
        let maxBackupsToKeep = 2 // Keep most recent 2 backups (including the current one)
        let fileManager = FileManager.default
        let backupDirectory = currentBackup.deletingLastPathComponent()
        
        do {
            // Get all backup files
            let directoryContents = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Filter for backup files only
            let backupFiles = directoryContents.filter { $0.lastPathComponent.hasPrefix("Depthful-backup-") && $0.lastPathComponent.hasSuffix(".sqlite") }
            
            // Skip if we don't have more than the max
            if backupFiles.count <= maxBackupsToKeep {
                return
            }
            
            // Sort by creation date, newest first
            let sortedBackups = try backupFiles.sorted { file1, file2 in
                // Get creation dates
                let attrs1 = try fileManager.attributesOfItem(atPath: file1.path)
                let attrs2 = try fileManager.attributesOfItem(atPath: file2.path)
                
                let date1 = attrs1[.creationDate] as? Date ?? Date.distantPast
                let date2 = attrs2[.creationDate] as? Date ?? Date.distantPast
                
                return date1 > date2
            }
            
            // Delete the oldest backups (keep the newest ones)
            for backupToDelete in sortedBackups.dropFirst(maxBackupsToKeep) {
                try fileManager.removeItem(at: backupToDelete)
                print("Removed old backup: \(backupToDelete.lastPathComponent)")
            }
        } catch {
            print("Failed to clean up old backups: \(error)")
            // Continue even if cleanup fails
        }
    }
    
    /// Resets the persistent store as a last resort recovery mechanism
    private func resetStore() -> Bool {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        // Get all files associated with the store
        let storeFolderURL = storeURL.deletingLastPathComponent()
        let storeFileName = storeURL.lastPathComponent
        let fileManager = FileManager.default
        
        do {
            // Create a recovery directory
            let recoveryURL = storeFolderURL.appendingPathComponent("Recovery-\(Date().timeIntervalSince1970)")
            try fileManager.createDirectory(at: recoveryURL, withIntermediateDirectories: true)
            
            // Move problematic files to recovery instead of deleting
            let storeFiles = try fileManager.contentsOfDirectory(at: storeFolderURL, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix(storeFileName) || $0.lastPathComponent.hasSuffix("sqlite") }
            
            for fileURL in storeFiles {
                let destination = recoveryURL.appendingPathComponent(fileURL.lastPathComponent)
                try fileManager.moveItem(at: fileURL, to: destination)
                print("Moved \(fileURL.lastPathComponent) to recovery folder")
            }
            
            // Limit the number of recovery folders
            cleanupOldRecoveryFolders(currentRecovery: recoveryURL)
            
            // Remove the old persistent stores
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
            
            // Configure a new store
            if let description = container.persistentStoreDescriptions.first {
                description.url = storeURL
                description.shouldMigrateStoreAutomatically = true
                description.shouldInferMappingModelAutomatically = true
            }
            
            // Try loading the stores again
            var loadSuccess = false
            var controller = self
            container.loadPersistentStores { (description, error) in
                if error == nil {
                    controller.isStoreLoaded = true
                    loadSuccess = true
                    print("Successfully recreated persistent store")
                } else {
                    print("Failed to recreate persistent store: \(error!)")
                }
            }
            
            // Configure view context if successful
            if loadSuccess {
                container.viewContext.automaticallyMergesChangesFromParent = true
                container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                return true
            }
            
            return false
        } catch {
            print("Failed during store reset: \(error)")
            return false
        }
    }
    
    /// Cleans up old recovery folders, keeping only the most recent ones
    private func cleanupOldRecoveryFolders(currentRecovery: URL) {
        let maxRecoveriesToKeep = 2 // Keep most recent 2 recovery folders (including the current one)
        let fileManager = FileManager.default
        let parentDirectory = currentRecovery.deletingLastPathComponent()
        
        do {
            // Get all directories in the parent folder
            let directoryContents = try fileManager.contentsOfDirectory(at: parentDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Filter for recovery folders only
            let recoveryFolders = directoryContents.filter { $0.lastPathComponent.hasPrefix("Recovery-") }
            
            // Skip if we don't have more than the max
            if recoveryFolders.count <= maxRecoveriesToKeep {
                return
            }
            
            // Sort by creation date, newest first
            let sortedRecoveries = try recoveryFolders.sorted { folder1, folder2 in
                // Get creation dates
                let attrs1 = try fileManager.attributesOfItem(atPath: folder1.path)
                let attrs2 = try fileManager.attributesOfItem(atPath: folder2.path)
                
                let date1 = attrs1[.creationDate] as? Date ?? Date.distantPast
                let date2 = attrs2[.creationDate] as? Date ?? Date.distantPast
                
                return date1 > date2
            }
            
            // Delete the oldest recovery folders (keep the newest ones)
            for folderToDelete in sortedRecoveries.dropFirst(maxRecoveriesToKeep) {
                try fileManager.removeItem(at: folderToDelete)
                print("Removed old recovery folder: \(folderToDelete.lastPathComponent)")
            }
        } catch {
            print("Failed to clean up old recovery folders: \(error)")
            // Continue even if cleanup fails
        }
    }
    
    private func setupRemoteChangeHandling() {
        let controller = self
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main) { _ in
                controller.handleRemoteChanges()
            }
    }
    
    private func setupBackgroundSaveHandling() {
        let controller = self
        NotificationCenter.default.addObserver(
            forName: UIScene.didEnterBackgroundNotification,
            object: nil,
            queue: .main) { _ in
                controller.saveViewContext()
            }
    }
    
    private func checkStoreVersion() {
        let key = "store_version"
        let defaults = UserDefaults.standard
        let previousVersion = defaults.integer(forKey: key)
        
        if previousVersion == 0 {
            print("New user detected - initializing store version to \(currentStoreVersion)")
            defaults.set(currentStoreVersion, forKey: key)
            return
        }
        
        if previousVersion < currentStoreVersion {
            print("Upgrading store from version \(previousVersion) to \(currentStoreVersion)")
            
            // Perform post-migration cleanup
            performPostMigrationCleanup()
            
            // Update stored version
            defaults.set(currentStoreVersion, forKey: key)
        } else {
            print("Store is already at version \(currentStoreVersion)")
        }
    }
    
    private func handleRemoteChanges() {
        let controller = self
        container.viewContext.perform {
            // First save any pending changes
            controller.saveViewContext()
            
            // Then deduplicate
            controller.deduplicateThoughts(in: controller.container.viewContext)
        }
    }
    
    private func saveViewContext() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
                print("Context saved successfully")
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    private func performPostMigrationCleanup() {
        let controller = self
        container.viewContext.perform {
            // Perform deduplication after migration
            controller.deduplicateThoughts(in: controller.container.viewContext)
            
            // Save any changes from deduplication
            controller.saveViewContext()
        }
    }

    private func deduplicateThoughts(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Thought> = Thought.fetchRequest()
        
        do {
            let thoughts = try context.fetch(fetchRequest)
            var thoughtsByKey = [String: [Thought]]()
            var duplicatesFound = false
            
            // Group thoughts by a composite key
            for thought in thoughts {
                // Create a unique key using multiple properties
                let content = thought.content ?? ""
                let dateString = thought.creationDate?.timeIntervalSince1970.description ?? ""
                let tag = thought.tag ?? ""
                let key = "\(content)_\(dateString)_\(tag)"
                
                if thoughtsByKey[key] == nil {
                    thoughtsByKey[key] = [thought]
                } else {
                    thoughtsByKey[key]?.append(thought)
                }
            }
            
            // Process duplicates
            for (_, duplicates) in thoughtsByKey where duplicates.count > 1 {
                duplicatesFound = true
                print("Found \(duplicates.count) duplicates for thought")
                
                // Sort by lastUpdated to find the most recent
                let sortedDuplicates = duplicates.sorted {
                    ($0.lastUpdated ?? Date.distantPast) > ($1.lastUpdated ?? Date.distantPast)
                }
                
                // Keep the most recent one and delete others
                let kept = sortedDuplicates[0]
                print("Keeping thought with date: \(kept.creationDate?.description ?? "unknown")")
                
                for duplicate in sortedDuplicates.dropFirst() {
                    print("Deleting duplicate with date: \(duplicate.creationDate?.description ?? "unknown")")
                    context.delete(duplicate)
                }
            }
            
            // Save if changes were made
            if context.hasChanges {
                try context.save()
                if duplicatesFound {
                    print("Successfully removed duplicates during deduplication")
                }
            }
        } catch {
            print("Error during deduplication: \(error)")
            // Rollback on error to ensure data consistency
            context.rollback()
        }
    }
    
    // Public method to force deduplication
    func performDeduplication() {
        let controller = self
        container.viewContext.perform {
            controller.deduplicateThoughts(in: controller.container.viewContext)
        }
    }
}
