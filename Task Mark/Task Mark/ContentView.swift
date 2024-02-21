// Created in New year 2024
// By Goood (Ratanapara) Choorat

import SwiftUI
import UIKit


class CustomCategoryManager: ObservableObject {
    @Published var savedCustomCategories: [CustomTaskCategory] = []

    init() {
        loadCustomCategories()
    }

    func saveCustomCategory(_ category: CustomTaskCategory) {
        if let index = savedCustomCategories.firstIndex(where: { $0.name == category.name }) {
            savedCustomCategories[index] = category
        } else {
            savedCustomCategories.append(category)
        }
        saveToUserDefaults()
    }

    func saveToUserDefaults() {
        let categoryDictionaries = savedCustomCategories.map { $0.dictionaryRepresentation }
        UserDefaults.standard.set(categoryDictionaries, forKey: "savedCustomCategories")
    }

    func loadCustomCategories() {
        if let categoryDictionaries = UserDefaults.standard.array(forKey: "savedCustomCategories") as? [[String: Any]] {
            savedCustomCategories = categoryDictionaries.compactMap { CustomTaskCategory(dictionary: $0) }
        }
    }
}


class UserDefaultsManager {
    static let shared = UserDefaultsManager()
    
    private init() {}
    
    func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }
    
    func save<T: Encodable>(_ value: T, forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
}
extension UserDefaultsManager {
    func loadTasks() -> [Task] {
        return load(forKey: UserDefaultsManager.tasksKey) ?? []
    }
    
    func saveTasks(_ tasks: [Task]) {
        save(tasks, forKey: UserDefaultsManager.tasksKey)
    }
    
    func loadArchiveTasks() -> [Task] {
        return load(forKey: UserDefaultsManager.archiveTasksKey) ?? []
    }
    
    func saveArchiveTasks(_ tasks: [Task]) {
        save(tasks, forKey: UserDefaultsManager.archiveTasksKey)
    }
}

extension UserDefaultsManager {
    static let tasksKey = "tasks"
    static let archiveTasksKey = "archiveTasks"
}


class UserDefaultsManagerWrapper: ObservableObject {
    let manager = UserDefaultsManager.shared
}


struct Task: Identifiable, Equatable, Hashable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var isCompleted: Bool = false
    var category: TaskCategory // type of task
    var customCategory: CustomTaskCategory?
    var categoryName: String {
        return category == .custom ? customCategory?.name ?? "" : category.rawValue
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, isCompleted, category, customCategory
    }
    
    func hash(into hasher: inout Hasher){
        hasher.combine(id)
    }
    
    static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.id == rhs.id
    }
    
}

struct CustomTaskCategory: Hashable, Codable, Equatable {
    let id: UUID
    let name: String
    
    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
    
    static func ==(lhs: CustomTaskCategory, rhs: CustomTaskCategory) -> Bool {
        return lhs.name == rhs.name
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
    
    // Convert CustomTaskCategory to dictionary
    var dictionaryRepresentation: [String: Any] {
        return [
            CodingKeys.id.rawValue: id.uuidString,
            CodingKeys.name.rawValue: name
        ]
    }
    
    // Initialize CustomTaskCategory from dictionary
    init?(dictionary: [String: Any]) {
        guard let idString = dictionary[CodingKeys.id.rawValue] as? String,
              let id = UUID(uuidString: idString),
              let name = dictionary[CodingKeys.name.rawValue] as? String else {
            return nil
        }
        self.id = id
        self.name = name
    }
}


enum TaskCategory: String, CaseIterable, Codable {
    case urgent = "Urgent"
    case nonUrgent = "Non-Urgent"
    case custom = "Custom"
}

let backgroundGradient = LinearGradient(
    colors: [Color.blue, Color.white],
    startPoint: .top, endPoint: .bottom)

struct ContentView: View {
    @State private var isAddingTask = false
    @State private var tasks: [Task] = []
    @State private var selectedTaskIndex: Int?
    @State private var showAlert = false
    @State private var archiveTasks: [Task] = []
    @State private var customTaskCategory: String = ""
    @StateObject private var customCategoryManager = CustomCategoryManager() // Initialize CustomCategoryManager
    
    // Create an instance of UserDefaultsManager
    @StateObject private var userDefaultsManagerWrapper = UserDefaultsManagerWrapper()
    
    var body: some View {
        ZStack {
            backgroundGradient
                .edgesIgnoringSafeArea(.all)
            
            if isAddingTask {
                AddNewTaskView(isAddingTask: $isAddingTask, tasks: $tasks, customCategoryManager: customCategoryManager, userDefaultsManager: userDefaultsManagerWrapper.manager)
            } else {
                VStack {
                    TabView {
                        // Main menu tab
                        TaskListView(tasks: $tasks, selectedTaskIndex: $selectedTaskIndex, archiveTasks: $archiveTasks, isAddingTask: $isAddingTask, customCategoryManager: customCategoryManager, userDefaultsManager: userDefaultsManagerWrapper.manager)
                            .tabItem {
                                Image(systemName: "house.fill")
                                Text("Main Menu")
                            }
                            .tag(1)
                        
                        // Archive tab
                        ArchivedTasksView(archiveTasks: $archiveTasks)
                            .tabItem {
                                Image(systemName: "archivebox.fill")
                                Text("Archive")
                            }
                            .tag(2)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Load tasks and archiveTasks using UserDefaultsManager instance
            tasks = userDefaultsManagerWrapper.manager.loadTasks()
            archiveTasks = userDefaultsManagerWrapper.manager.loadArchiveTasks()
            if tasks.isEmpty {
                print("No tasks loaded from UserDefaults")
            } else {
                print("Tasks loaded successfully from UserDefaults")
            }
            
            // Load custom categories
            customCategoryManager.loadCustomCategories()
            
            // Subscribe to app state changes to save tasks and archiveTasks
            NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                self.userDefaultsManagerWrapper.manager.saveTasks(self.tasks)
                self.userDefaultsManagerWrapper.manager.saveArchiveTasks(self.archiveTasks)
            }
        }
        .onReceive(customCategoryManager.$savedCustomCategories) { customCategories in
            // Save custom categories to UserDefaults using UserDefaultsManager instance
            UserDefaults.standard.set(customCategories, forKey: "savedCustomCategories")
        }
    }
}


struct ArchivedTasksView: View {
    @Binding var archiveTasks: [Task]
    
    var body: some View {
        VStack {
            Text("Archived Tasks")
                .font(.title)
                .padding(.top, 20)
            
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading) {
                    ForEach(archiveTasks) { task in
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .foregroundColor(.white)
                                .padding()
                            
                            Text(task.description)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct TaskRowView: View {
    var task: Task
    @Binding var selectedTaskIndex: Int?
    @Binding var showAlert: Bool
    var tasks: [Task]
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                // Icon based on task category
                if task.category == .custom {
                    Image(systemName: iconForCustomCategory(task.customCategory?.name ?? ""))
                        .foregroundColor(colorForTaskCategory(task.category))
                        .onTapGesture {
                            if let index = tasks.firstIndex(of: task) {
                                selectedTaskIndex = index
                            }
                            showAlert = true
                            print("Checkbox tapped. selectedTaskIndex: \(selectedTaskIndex ?? -1)")
                        }
                } else {
                    Image(systemName: iconForTaskCategory(task.category))
                        .foregroundColor(colorForTaskCategory(task.category))
                        .onTapGesture {
                            if let index = tasks.firstIndex(of: task) {
                                selectedTaskIndex = index
                            }
                            showAlert = true
                            print("Checkbox tapped. selectedTaskIndex: \(selectedTaskIndex ?? -1)")
                        }
                }
                
                Button(action: {
                    if selectedTaskIndex == tasks.firstIndex(of: task) {
                        selectedTaskIndex = nil
                    } else {
                        selectedTaskIndex = tasks.firstIndex(of: task)
                    }
                    print("Checkbox tapped. selectedTaskIndex: \(selectedTaskIndex ?? -1)")
                }) {
                    Text(task.title)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .font(.custom("SukhumvitSet-Medium.ttf", size: 20))
                        .padding(.leading, 8)
                }
            }
            
            if let selectedTaskIndex = selectedTaskIndex, selectedTaskIndex == tasks.firstIndex(of: task) {
                // Dropdown button for description
                DisclosureGroup("Description") {
                    Text(task.description)
                        .padding()
                }
                .padding(.leading, 25)
            }
        }
        .padding(.vertical, 5)
    }
    
    func iconForTaskCategory(_ category: TaskCategory) -> String {
        switch category {
        case .urgent:
            return "clock"
        case .nonUrgent:
            return "clock.fill"
        case .custom:
            return "clock.arrow.circlepath"
        }
    }
    
    // Function to return appropriate color based on task category
    func colorForTaskCategory(_ category: TaskCategory) -> Color {
        switch category {
        case .urgent:
            return .red
        case .nonUrgent:
            return .green
        case .custom:
            return .blue
        }
    }
    func iconForCustomCategory(_ category: String) -> String {
        switch category {
        case "Home":
            return "house"
        case "Friend":
            return "person.2"
        case "Family":
            return "person.3"
        case "School":
            return "graduationcap"
        case "Work":
            return "briefcase"
        default:
            return "clock.arrow.circlepath" // Default icon for other categories
        }
    }
}

struct TaskListView: View {
    @Binding var tasks: [Task]
    @Binding var selectedTaskIndex: Int?
    @Binding var archiveTasks: [Task]
    @Binding var isAddingTask: Bool
    @ObservedObject var customCategoryManager: CustomCategoryManager // Inject CustomCategoryManager
    var userDefaultsManager: UserDefaultsManager // Inject UserDefaultsManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var buttonForegroundColor: Color = .white
    @State private var buttonBackgroundColor: Color = .blue
    @State private var buttonStrokeColor: Color = .blue
    @State private var showAlert = false
    
    var groupedTasks: [String: [Task]] {
        Dictionary(grouping: tasks.sorted(by: { $0.category.rawValue < $1.category.rawValue })) { $0.categoryName }
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .top, spacing: 15) {
                Image(systemName: "paperplane.circle.fill")
                    .imageScale(.large)
                    .foregroundColor(.blue)
                Text("Task Mark")
                    .font(Font.custom("SukhumvitSet-Medium.ttf", size: 35))
                    .padding(.bottom, 8)
            }
            
            Spacer()
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        isAddingTask = true
                    }) {
                        HStack {
                            Image(systemName: "plus.app")
                                .imageScale(.medium)
                                .foregroundColor(Color.primary) // Use primary color for the image
                                .padding(8)
                            Text("Add new Task")
                                .padding()
                                .foregroundColor(Color.primary) // Use primary color for the text
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10.0)
                                .stroke(lineWidth: 2.0)
                                .foregroundColor(Color.primary) // Use primary color for the stroke
                        )
                    }
                    .sheet(isPresented: $isAddingTask) {
                        TaskListView(tasks: $tasks, selectedTaskIndex: $selectedTaskIndex, archiveTasks: $archiveTasks, isAddingTask: $isAddingTask, customCategoryManager: customCategoryManager, userDefaultsManager: userDefaultsManager)
                            .onAppear {
                                updateButtonColors() // Call updateButtonColors on appear
                            }
                            .onChange(of: colorScheme) { _ in
                                updateButtonColors() // Call updateButtonColors on color scheme change
                            }
                    }
                }
                
                
                List {
                    ForEach(groupedTasks.keys.sorted(), id: \.self) { key in
                        Section(header: Text(key)) {
                            ForEach(groupedTasks[key]!, id: \.self) { task in
                                TaskRowView(task: task, selectedTaskIndex: $selectedTaskIndex, showAlert: $showAlert, tasks: tasks)
                            }
                        }
                    }
                }
            }
            .navigationBarItems(leading: EmptyView())
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Move to Archive?"),
                    message: Text("Do you want to move this task to the archive?"),
                    primaryButton: .default(Text("Yes")) {
                        if let selectedTaskIndex = selectedTaskIndex {
                            let movedTask = tasks[selectedTaskIndex] // Get the task to be moved
                            archiveTasks.append(movedTask) // Append to the archive list
                            tasks.remove(at: selectedTaskIndex) // Remove from the main task list
                            self.selectedTaskIndex = nil // Reset selectedTaskIndex
                            print("Task moved to archive.")
                        }
                    },
                    secondaryButton: .cancel(Text("No")) {
                        // No action needed when user chooses not to move to archive
                        self.selectedTaskIndex = nil // Reset selectedTaskIndex
                    }
                )
            }
        }
        .onAppear {
            customCategoryManager.loadCustomCategories()
        }
    }
    private var buttonColor: Color {
        return colorScheme == .dark ? .white : .blue
    }
    private func updateButtonColors() {
        // Define colors for light mode
        let lightButtonColor: Color = .indigo
        let lightTextColor: Color = .black
        let lightStrokeColor: Color = .indigo
        
        // Define colors for dark mode
        let darkButtonColor: Color = .blue
        let darkTextColor: Color = .white
        let darkStrokeColor: Color = .blue
        
        // Determine button colors based on color scheme
        let buttonColor: Color
        let textColor: Color
        let strokeColor: Color
        
        if colorScheme == .dark {
            buttonColor = darkButtonColor
            textColor = darkTextColor
            strokeColor = darkStrokeColor
        } else {
            buttonColor = lightButtonColor
            textColor = lightTextColor
            strokeColor = lightStrokeColor
        }
        
        // Update button appearance
        // You can set specific properties like foreground color, background color, and stroke color
        buttonForegroundColor = textColor
        buttonBackgroundColor = buttonColor
        buttonStrokeColor = strokeColor
    }
}

struct AddNewTaskView: View {
    @Binding var isAddingTask: Bool
    @Binding var tasks: [Task]
    @ObservedObject var customCategoryManager: CustomCategoryManager
    var userDefaultsManager: UserDefaultsManager
    
    @State private var taskTitle: String = ""
    @State private var taskDescription: String = ""
    @State private var selectedCategoryIndex: Int = 0
    @State private var customTaskCategoryName: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Name a fun Task", text: $taskTitle)
                    .padding()
                
                TextField("Enter Task Description", text: $taskDescription)
                    .padding()
                
                Picker(selection: $selectedCategoryIndex, label: Text("Select Category")) {
                    ForEach(0..<pickerCategories().count, id: \.self) { index in
                        Text(self.pickerCategories()[index])
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 150)
                
                if selectedCategoryIndex == pickerCategories().count - 1 {
                    TextField("Add new Task Category", text: $customTaskCategoryName)
                        .padding()
                }
                
                Button("Save") {
                    saveTask()
                    isAddingTask = false
                }
                .padding()
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(10.0)
            }
            .padding()
            .navigationBarTitle("Add New Task", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                isAddingTask = false
            })
        }
        .background(Color.white.opacity(0.5))
    }
    
    private func saveTask() {
        guard selectedCategoryIndex >= 0 && selectedCategoryIndex < pickerCategories().count else {
            print("Error: Invalid selectedCategoryIndex")
            return
        }
        
        let selectedCategory = pickerCategories()[selectedCategoryIndex]
        
        if selectedCategory == "Add new Task Category" {
            let trimmedCategoryName = customTaskCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedCategoryName.isEmpty {
                if customCategoryManager.savedCustomCategories.contains(where: { $0.name == trimmedCategoryName }) {
                    // Handle duplicate category name
                    showAlert()
                } else {
                    let newCustomCategory = CustomTaskCategory(name: trimmedCategoryName)
                    customCategoryManager.saveCustomCategory(newCustomCategory)
                    tasks.append(Task(title: taskTitle, description: taskDescription, category: .custom, customCategory: newCustomCategory))
                }
            }
        } else {
            let category = TaskCategory(rawValue: selectedCategory) ?? .nonUrgent
            tasks.append(Task(title: taskTitle, description: taskDescription, category: category))
        }
        
        // Save tasks to UserDefaults
        userDefaultsManager.saveTasks(tasks)
    }
    
    private func showAlert() {
        // Show alert for duplicate category name
    }
    
    private func pickerCategories() -> [String] {
        var categories = ["Non-urgent", "Urgent"]
        categories.append(contentsOf: customCategoryManager.savedCustomCategories.map { $0.name })
        categories.append("Add new Task Category")
        
        // Reorder the categories
        categories.sort {
            if $0 == "Non-urgent" || $1 == "Add new Task Category" {
                return true
            } else if $0 == "Urgent" {
                return $1 != "Non-urgent" && $1 != "Add new Task Category"
            } else {
                return false
            }
        }
        
        return categories
    }
}


//struct TaskPreview: View {
//    var title: String
//    var description: String
//    var category: TaskCategory
//    
//    var body: some View {
//        VStack(alignment: .leading) {
//            Text("Preview:")
//                .font(.headline)
//            Text("Title: \(title)")
//            Text("Description: \(description)")
//            Text("Category: \(category.rawValue)")
//        }
//    }
//}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
