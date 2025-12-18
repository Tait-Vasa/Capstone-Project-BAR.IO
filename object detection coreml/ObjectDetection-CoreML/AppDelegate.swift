//
//  AppDelegate.swift
//  SSDMobileNet-CoreML
//
//  Created by GwakDoyoung on 01/02/2019.
//

import UIKit

/// The application delegate.
///
/// `AppDelegate` is responsible for responding to high-level application
/// lifecycle events such as launch, backgrounding, foregrounding,
/// and termination.
///
/// In this project, the delegate uses the default UIKit lifecycle behavior
/// and does not introduce custom logic beyond the standard template.
/// It exists primarily to support application startup and state transitions.
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    /// The main window used to display the app’s user interface.
    ///
    /// This property is managed by UIKit and represents the root window
    /// that hosts the app’s view controller hierarchy.
    var window: UIWindow?

    /// Called when the application has finished launching.
    ///
    /// This method provides an opportunity to perform any final initialization
    /// before the app’s user interface is presented to the user.
    ///
    /// In this project, no additional customization is performed at launch.
    ///
    /// - Parameters:
    ///   - application: The singleton app object.
    ///   - launchOptions: A dictionary indicating the reason the app was launched.
    /// - Returns: `true` to indicate successful launch.
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    /// Notifies the app that it is about to move from the active to inactive state.
    ///
    /// This transition can occur due to temporary interruptions
    /// such as incoming phone calls, notifications, or when the user
    /// begins quitting the app.
    ///
    /// This method is typically used to pause ongoing tasks,
    /// disable timers, or throttle down performance-sensitive operations.
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state.
    }

    /// Notifies the app that it has entered the background.
    ///
    /// Once in the background, the app should release shared resources,
    /// save user data, and invalidate timers to conserve system resources.
    ///
    /// If the app supports background execution, this method may be called
    /// instead of `applicationWillTerminate(_:)` when the user quits.
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources and save user data.
    }

    /// Notifies the app that it is transitioning from the background to the foreground.
    ///
    /// This method allows the app to undo changes made when entering the background
    /// and prepare the user interface to become active again.
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from background to active state.
    }

    /// Notifies the app that it has become active.
    ///
    /// This method is typically used to restart tasks that were paused
    /// while the app was inactive or in the background and to refresh
    /// the user interface if needed.
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused while the application was inactive.
    }

    /// Notifies the app that it is about to terminate.
    ///
    /// This method provides a final opportunity to save data
    /// or perform cleanup before the app exits.
    ///
    /// In most cases, backgrounded apps are terminated without
    /// this method being called.
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate.
    }
}
