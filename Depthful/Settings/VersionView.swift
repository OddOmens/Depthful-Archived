import SwiftUI

struct VersionView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Section {
                    Text("Release 2025.12.1")
                        .font(.headline)
                    Text("Release Date: December 2025")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text("""
                        • Updated the "Request a Feature" link
                        • Updated the "Report a Issue" link
                        • Updated the "Documentation" link
                        • Removed the "Support the App" pages
                        • Removed the "Support the App" pop up
                        • Removed "Related Apps" section
                        """).font(.caption)
                }
                
                Divider()
                
                Section {
                    Text("Release 2025.09.1")
                        .font(.headline)
                    Text("Release Date: September 2025")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added support for iOS26 and Liquid Glass
                        • Added support for iPad
                        • Added Support Popup every 10 launches
                        • Removed Thought title to make more room
                        • Updated the review popup to show on the 2nd and 5th launch
                        • Updated Left Arrow to Xmark on "Custom Tag" view
                        • Fixed Search bar padding
                        • Fixed Recording Gallery arrow from pointing down to left
                        • Fixed missing xmark icon
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 4.0.1".localized)
                        .font(.headline)
                    Text("Release Date: May 28th, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Fixed Recording Gallery arrow from pointing down to left
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 4.0.0".localized)
                        .font(.headline)
                    Text("Release Date: May 28th, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added 9 new languages German, Spanish, French, Hindi, Japanese, Korean, Portuguese, Chinese (Simplified), and Arabic
                        • Added language section in settings
                        • Added Voice Recording option for thoughts
                        • Added transcribe feature for voice recordings
                        • Added section in "Tag View" to easily see your selected tags
                        • Added ability to add multiple tags to thoughts
                        • Added ability to search for multiple tags (Notes must have all to be filtered)
                        • Added section in "Select Tags" for active tags
                        • Added option to hide last view date
                        • Added double tap to enable or disable markdown mode
                        • Added toolbar with markdown tools
                        • Added image compression for uploaded images at 85% instead of 100%
                        • Rebuilt the entire saving process for thoughts
                        • Rebuilt the syncing process for thoughts and images
                        • Updated Analytics Tag count to include custom tags
                        • Updated image preview to show 4 images instead of 3
                        • Updated "Viewed XXm ago" to just "XXm ago" to save space
                        • Removed image scroll in Thought View in replace of a dedicated gallery 
                        • Removed Tag Distribution in Analytics (No use)
                        • Removed Most Recent section in "Select Tags" to make room
                        • Removed "Afterwards" from app list
                        • Removed Help button (Just email support instead)
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 3.1.1".localized)
                        .font(.headline)
                    Text("Release Date: April 11th, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Fixed auto-save bug when creating new thought
                        • Fixed analytics label
                        • Fixed analytics bug showing deleted tags
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 3.1.0".localized)
                        .font(.headline)
                    Text("Release Date: April 1st, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added "Z to A" and "Least Recently Viewed" to sort filters
                        • Added menu icon to home screen for better organize and clean up UI
                        • Added option to hide photos from preview
                        • Added display option to display entire thought
                        • Added ability to bookmark thoughts from main view
                        • Added menu icon to thought view for better organize and clean up UI
                        • Added "Clear Tag" button when searching a tag with no results
                        • Updated grid mode to actually stay in grid mode
                        • Updated favorite icon from a star to a bookmark
                        • Updated the tag selection view to be more fluid
                        • Updated the date selector if changing creation date for thought
                        • Updated home screen images to only show three then a numeral count
                        • Fixed critical bug that was hiding custom tags
                        • Fixed "Recent Tags" to reflect changes made to tags
                        • Fixed image saving bug while in a thought
                        • Removed grid mode (visual updates causing this style to not work)
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 3.0.0".localized)
                        .font(.headline)
                    Text("Release Date: March 27th, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added option to favorite thoughts
                        • Added new filter for favorites
                        • Added "System" to theme selector
                        • Added support prompt for every 45 launches (Clicking Support will turn this off as well)
                        • Upgraded to iOS 18 Deployment
                        • Upgraded CoreData Model from 3 to 4
                        • Updated persistence and migration functions (Better fix any duplications)
                        • Fixed some depreciated code to fall in line with iOS 18
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 2.1.2".localized)
                        .font(.headline)
                    Text("Release Date: March 22nd, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added "Afternoon" to apps list
                        • Fixed Tag Filter Bug
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 2.1.1".localized)
                        .font(.headline)
                    Text("Release Date: March 1st, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Fixed Full Image viewer close button being hidden
                        • Fixed Full Image viewer swipe down to close
                        • Fixed Analytics most active day
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 2.1.0".localized)
                        .font(.headline)
                    Text("Release Date: February 28, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added entry sorting
                        • Added image swipping in full image view
                        • Updated image picker to let you select more than one image
                        • Updated default organization to be most recent creation date
                        • Updated Export and Import (Does not support images)
                        • Moved the Support Depthful button to the settings view
                        • Fixed image viewing bug
                        • Fixed creation date to allow you to set properly
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 2.0.1".localized)
                        .font(.headline)
                    Text("Release Date: Released with 2.1.0".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Updated verbiage on analytics page
                        • Removed "All Tags" scroll in Analytics
                        • Fixed analytics icon
                        • Fixed data mapping (Sorry for duplicates)
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 2.0.0".localized)
                        .font(.headline)
                    Text("Release Date: February 26, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added support for photos
                        • Added analytics view
                        • Added "Created On" date for thoughts (Changeable)
                        • Added "Last Updated" date for thoughts
                        • Added dedicated "Clear Tag" button in Select Tag view
                        • Added Search in Select Tag view
                        • Added "Recently Used" in Select Tag view
                        • Added "Goal", "Story", "Idea", "Journal", and "Learning" tags
                        • Added thought count
                        • Added option to support app
                        • Updated default tag color scheme
                        • Updated the UI functionally and visually
                        • Fixed Version History view
                        • Fixed an iCloud bug
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.6.2".localized)
                        .font(.headline)
                    Text("Release Date: February 15, 2025".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Adjusted design of Add / Edit Custom Tag views
                        • Adjusted size oftags in Select Tag view
                        • Fixed bug causing custom tags not to save in iCloud
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.6.1".localized)
                        .font(.headline)
                    Text("Release Date: December 30, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Updated report bug link
                        • Updated request feature link
                        • Fixed a depreciated section of code
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.6.0".localized)
                        .font(.headline)
                    Text("Release Date: December 6, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added 'Last Viewed' to whats in your mind
                        • Updated Select Tag and Add Tag layouts
                        • Fixed possible save bug when updating
                        • Fixed 'Help Center' icon
                        • Fixed Export function
                        • Fixed Import function
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.5.0".localized)
                        .font(.headline)
                    Text("Release Date: September 13, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Refreshed the design for List and Grid views
                        • Added Custom Tags (With color picker)
                        • Added support for iOS 18
                        • Added help center link
                        • Updated Dark Theme
                        • Updated Privacy and Terms links to new website
                        • Updated save function to better protect your thoughts
                        • Fixed Dark Theme
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.4.1".localized)
                        .font(.headline)
                    Text("Release Date: August 5th, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Updated Term of Service is now hosted outside the app
                        • Updated Privacy Policy is now hosted outside the app
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.4.0".localized)
                        .font(.headline)
                    Text("Release Date: July 15th, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added alternative app icons
                        • Updated "Theme" to "Dark Theme"
                        • Fixed Related Apps section
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.3.0".localized)
                        .font(.headline)
                    Text("Release Date: May 18th, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added export button for all thoughts in settings
                        • Added export button for single thought
                        • Added import button for mass thoughts in settings
                        • Added ability to add a thought based on empty search results
                        • Added delete thoughts button that will delete all thoughts
                        • Added delete option in grid view. Tap and hold to prompt deletion
                        • Added tags for Advice, Inspiration, Milestones and Regrets
                        • Fixed thought list padding
                        • Fixed grid view justification
                        • Fixed bottom bar divider bug when searching
                        • Reverted tags corner roundness back to what it was
                        • Export support for .TXT .MD and .CSV
                        • Import support for .TXT and .MD
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.2.3".localized)
                        .font(.headline)
                    Text("Release Date: April 24, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Adjusted spacing between tag icon and tag type
                        • Tag types are now tappable to change tags
                        • Tag types have fully rounded edges
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.2.2".localized)
                        .font(.headline)
                    Text("Release Date: April 16, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Adjusted review prompt to show after 7th and 12th launch of the app
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.2.1".localized)
                        .font(.headline)
                    Text("Release Date: April 14, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Fixed plus icon not showing for adding new thought
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.2.0".localized)
                        .font(.headline)
                    Text("Release Date: April 13, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Added Grid View for viewing your thoughts
                        • Added Copy Button + notification to copy thoughts
                        • Added Apple PrivacyInfo
                        • Updated "Related Apps" Section
                        • Updated from system to custom icons
                        • Fixed dark theme issue
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.1.0".localized)
                        .font(.headline)
                    Text("Release Date: March 26th, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • Tweaked the Coloring of the UI
                        • Increased the Tag buttons
                        • Added "Gratitude" and "Experience" tags
                        • Fixed Theme Toggle Bug
                        • Refined the Depthful Logo to be inline with the rest of the apps
                        """).font(.caption)
                }
                
                Divider().padding()
                
                Section {
                    Text("Version 1.0.0".localized)
                        .font(.headline)
                    Text("Release Date: March 14th, 2024".localized)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("""
                        • The Initial Release of Depthful, a mind compainion app to make your thoughts more oragnized and streamlined
                        """).font(.caption)
                }
            }.padding()
            .navigationTitle("Verizon History".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("arrow-left")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(Color.colorPrimary)
                            .scaledToFit()
                            .frame(width: 22, height: 22)
                            
                    }
                }
            }
        }
    }
}
