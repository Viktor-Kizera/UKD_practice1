//
//  main.swift
//  pracrice1UKD
//
//  Created by Viktor Kizera on 3/23/25.
//

import Foundation

// MARK: - Models
struct User: Codable {
    let name: String
    let email: String
}

// MARK: - Interfaces/Protocols

// Data Access Layer Protocol
protocol UserDataAccessProtocol {
    func getUsers() -> [User]
    func addUser(_ user: User) -> Bool
    func deleteUser(withEmail email: String) -> Bool
    func save()
}

// Business Logic Layer Protocol
protocol UserServiceProtocol {
    func getAllUsers() -> [User]
    func createUser(name: String, email: String) -> (success: Bool, message: String)
    func removeUser(email: String) -> (success: Bool, message: String)
}

// MARK: - Data Access Layer
class UserFileRepository: UserDataAccessProtocol {
    private var users: [User] = []
    private let fileURL: URL
    
    init() {
        // Створюємо URL для файлу в тимчасовій директорії (для Playground)
        let temporaryDirectory = FileManager.default.temporaryDirectory
        fileURL = temporaryDirectory.appendingPathComponent("users.json")
        
        // Завантажуємо дані при ініціалізації
        loadData()
    }
    
    private func loadData() {
        do {
            // Перевіряємо, чи існує файл
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                users = try JSONDecoder().decode([User].self, from: data)
                print("Дані завантажено з: \(fileURL.path)")
            } else {
                users = []
                print("Файл не існує. Створено порожній список користувачів.")
            }
        } catch {
            print("Помилка завантаження даних: \(error)")
            users = []
        }
    }
    
    func getUsers() -> [User] {
        return users
    }
    
    func addUser(_ user: User) -> Bool {
        // Перевіряємо, чи не існує вже такий email
        if users.contains(where: { $0.email == user.email }) {
            return false
        }
        
        users.append(user)
        save()
        return true
    }
    
    func deleteUser(withEmail email: String) -> Bool {
        let initialCount = users.count
        users.removeAll(where: { $0.email == email })
        
        if users.count < initialCount {
            save()
            return true
        }
        return false
    }
    
    func save() {
        do {
            let data = try JSONEncoder().encode(users)
            try data.write(to: fileURL)
            print("Дані збережено у: \(fileURL.path)")
        } catch {
            print("Помилка збереження даних: \(error)")
        }
    }
}

// MARK: - Business Logic Layer
class UserService: UserServiceProtocol {
    private let repository: UserDataAccessProtocol
    
    init(repository: UserDataAccessProtocol) {
        self.repository = repository
    }
    
    func getAllUsers() -> [User] {
        return repository.getUsers()
    }
    
    func createUser(name: String, email: String) -> (success: Bool, message: String) {
        // Валідація даних
        if name.isEmpty {
            return (false, "Ім'я не може бути порожнім")
        }
        
        if !isValidEmail(email) {
            return (false, "Невірний формат email")
        }
        
        let newUser = User(name: name, email: email)
        if repository.addUser(newUser) {
            return (true, "Користувача \(name) успішно додано")
        } else {
            return (false, "Користувач з email \(email) вже існує")
        }
    }
    
    func removeUser(email: String) -> (success: Bool, message: String) {
        if repository.deleteUser(withEmail: email) {
            return (true, "Користувача з email \(email) видалено")
        } else {
            return (false, "Користувача з email \(email) не знайдено")
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        // Простіша та надійніша перевірка email
        let components = email.components(separatedBy: "@")
        if components.count != 2 { return false }
        
        let localPart = components[0]
        let domainPart = components[1]
        
        // Перевірка на порожні частини
        if localPart.isEmpty || domainPart.isEmpty { return false }
        
        // Перевірка, що домен містить принаймні одну крапку
        if !domainPart.contains(".") { return false }
        
        // Перевірка, що після останньої крапки є принаймні 2 символи (домен верхнього рівня)
        let domainComponents = domainPart.components(separatedBy: ".")
        if let tld = domainComponents.last, tld.count < 2 { return false }
        
        // Додаткова перевірка на недопустимі символи (опціонально)
        let allowedLocalChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_+%"
        let allowedDomainChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-"
        
        for char in localPart {
            if !allowedLocalChars.contains(char) {
                return false
            }
        }
        
        for char in domainPart {
            if !allowedDomainChars.contains(char) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Presentation Layer
class UserConsoleManager {
    private let userService: UserServiceProtocol
    
    init(userService: UserServiceProtocol) {
        self.userService = userService
    }
    
    func start() {
        print("Консольний додаток управління користувачами запущено!")
        showMainMenu()
    }
    
    private func showMainMenu() {
        while true {
            print("\n===== МЕНЮ =====")
            print("1. Вивести список користувачів")
            print("2. Додати нового користувача")
            print("3. Видалити користувача")
            print("0. Вихід")
            print("Оберіть опцію (0-3): ", terminator: "")
            
            guard let choice = readLine(), let option = Int(choice) else {
                print("Невірний ввід. Спробуйте ще раз.")
                continue
            }
            
            switch option {
            case 0:
                print("Дякуємо за використання програми!")
                return
            case 1:
                displayUsers()
            case 2:
                addUser()
            case 3:
                deleteUser()
            default:
                print("Невірна опція. Спробуйте ще раз.")
            }
        }
    }
    
    private func displayUsers() {
        let users = userService.getAllUsers()
        
        if users.isEmpty {
            print("Список користувачів порожній")
            return
        }
        
        print("\n===== СПИСОК КОРИСТУВАЧІВ =====")
        for (index, user) in users.enumerated() {
            print("\(index + 1). Ім'я: \(user.name), Email: \(user.email)")
        }
    }
    
    private func addUser() {
        print("\n===== ДОДАВАННЯ НОВОГО КОРИСТУВАЧА =====")
        print("Введіть ім'я: ", terminator: "")
        guard let name = readLine(), !name.isEmpty else {
            print("Ім'я не може бути порожнім")
            return
        }
        
        print("Введіть email: ", terminator: "")
        guard let email = readLine(), !email.isEmpty else {
            print("Email не може бути порожнім")
            return
        }
        
        let result = userService.createUser(name: name, email: email)
        print(result.message)
    }
    
    private func deleteUser() {
        print("\n===== ВИДАЛЕННЯ КОРИСТУВАЧА =====")
        print("Введіть email користувача для видалення: ", terminator: "")
        guard let email = readLine(), !email.isEmpty else {
            print("Email не може бути порожнім")
            return
        }
        
        let result = userService.removeUser(email: email)
        print(result.message)
    }
}

// MARK: - Application Setup and Entry Point
func setupAndRun() {
    // Ініціалізація шарів
    let repository = UserFileRepository()
    let service = UserService(repository: repository)
    let consoleManager = UserConsoleManager(userService: service)
    
    // Запуск програми
    consoleManager.start()
}

// Запуск програми
setupAndRun()

//
