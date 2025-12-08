import Foundation
import SwiftUI

// MARK: - Supported Languages
enum AppLanguage: String, CaseIterable, Identifiable {
    case french = "fr"
    case english = "en"
    case arabic = "ar"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "English"
        case .arabic: return "العربية"
        }
    }
    
    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇬🇧"
        case .arabic: return "🇹🇳"
        }
    }
    
    var isRTL: Bool {
        self == .arabic
    }
}

// MARK: - Localization Manager
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("appLanguage") private var storedLanguage: String = "fr"
    
    @Published var currentLanguage: AppLanguage = .french {
        didSet {
            storedLanguage = currentLanguage.rawValue
            objectWillChange.send()
        }
    }
    
    private init() {
        if let lang = AppLanguage(rawValue: storedLanguage) {
            currentLanguage = lang
        }
    }
    
    // MARK: - Localized Strings
    func localized(_ key: LocalizedKey) -> String {
        return key.value(for: currentLanguage)
    }
}

// MARK: - Localized Keys
enum LocalizedKey {
    // Profile View
    case profile
    case darkMode
    case language
    case sessionsForYou
    case referFriend
    case shareProfile
    case myAnnouncements
    case myPromos
    case settings
    case logout
    case notConnected
    case login
    case loadingProfile
    case skillsTeaching
    case skillsLearning
    case badges
    case referralCode
    case remainingInvites
    case shareCode
    case close
    case sponsorship
    
    // Create Session
    case createSessionTitle
    case createSessionSubtitle
    case stepSession
    case stepPlanning
    case stepInvitations
    case sessionTitle
    case sessionTitlePlaceholder
    case description
    case descriptionPlaceholder
    case skill
    case addSkill
    case customSkillPlaceholder
    case sessionDate
    case startTime
    case duration
    case membersJoin
    case membersJoinSubtitle
    case participantEmail
    case emailPlaceholder
    case enterEmailError
    case invalidEmailError
    case participantExistsError
    case participantNotFoundError
    case loadSuggestionsError
    case sessionMode
    case online
    case inPerson
    case meetingLink
    case meetingLinkPlaceholder
    case meetingLocation
    case meetingLocationPlaceholder
    case selectOnMap
    case back
    case continueButton
    case creatingButton
    case createSessionButton
    case titleRequiredError
    case skillRequiredError
    case participantRequiredError
    case locationRequiredError
    case userNotConnectedError
    case creationError
    case fetchAvailabilityError
    
    // Common
    case cancel
    case save
    case error
    case success
    case loading
    
    // Sessions
    case sessions
    case createSession
    case upcomingSessions
    case pastSessions
    
    // Messages
    case messages
    case newMessage
    case typeMessage
    
    // Discover
    case discover
    case noMoreUsers
    case itsAMatch
    case sendMessage
    case keepSwiping
    
    // Tabs
    case tabDiscover
    case tabMessages
    case tabSessions
    case tabProgress
    case tabMap
    
    // Auth
    case email
    case password
    case forgotPassword
    case signUp
    case signIn
    case dontHaveAccount
    case alreadyHaveAccount
    case username
    case fullName
    case confirmPassword
    case welcomeBack
    case createAccount
    case rememberMe
    case validateCode
    case optional
    case orContinueWith
    
    // Notifications
    case notifications
    case markAllRead
    case noNotifications
    
    // Discover View
    case profiles
    case announcements
    case promos
    case noProfiles
    case reloadProfiles
    case noAnnouncements
    case noPromos
    case searchAnnouncement
    case searchPromo
    case youAndUserInterested
    case keepDiscovering
    case teaches
    case learns
    case filtersComingSoon
    case sort
    case filters
    case resetFilters
    case withImageOnly
    case category
    case city
    case activeOnly
    case minDiscount
    case until
    
    // Sessions View
    case mySessions
    case newSession
    case upcoming
    case completed
    case postponed
    case thisWeek
    case all
    case sessionUntitled
    case plan
    case postpone
    case leaveReview
    case join
    case proposeNewTime
    case rescheduleProposal
    case waitingForResponses
    case youResponded
    case yes
    case no
    case accept
    case decline
    case sendProposal
    case messageToMembers
    case rescheduleSession
    case confirmPostpone
    case areYouSurePostpone
    case date
    case time
    case newDate
    
    // Chat View
    case noConversations
    case chooseConversation
    case searchMentor
    case startConversation
    case replyTo
    case writeMessage
    case planSession
    case messageDeleted
    case reply
    case react
    case delete
    case recipient
    case emailOrUsername
    case subject
    case creating
    case newConversation
    case create
    case searching
    
    // Weekly Objectives
    case weeklyObjectiveTitle
    case noActiveObjective
    case createObjectivePrompt
    case createObjective
    case dailyTasks
    case todayTask
    case today
    case tasksCompleted
    case deleteObjective
    case objectiveDetails
    case objectiveTitlePlaceholder
    case targetHours
    case dates
    case startDate
    case endDate
    case dailyTasks7
    case taskPlaceholder
    case newObjective
    case history
    case noHistory
    case done
    
    func value(for language: AppLanguage) -> String {
        switch language {
        case .french:
            return frenchValue
        case .english:
            return englishValue
        case .arabic:
            return arabicValue
        }
    }
    
    private var frenchValue: String {
        switch self {
        case .createSessionTitle: return "Créer une nouvelle session ⭐️"
        case .createSessionSubtitle: return "Partagez vos compétences avec la communauté"
        case .stepSession: return "Session"
        case .stepPlanning: return "Planning"
        case .stepInvitations: return "Invitations"
        case .sessionTitle: return "Titre de la session"
        case .sessionTitlePlaceholder: return "Ex: Atelier iOS"
        case .description: return "Description"
        case .descriptionPlaceholder: return "Décrivez le déroulement de la session..."
        case .skill: return "Compétence (Skill)"
        case .addSkill: return "Ajouter une compétence"
        case .customSkillPlaceholder: return "Compétence personnalisée"
        case .sessionDate: return "Date de la session"
        case .startTime: return "Heure de début"
        case .duration: return "Durée"
        case .membersJoin: return "Les autres membres vont rejoindre"
        case .membersJoinSubtitle: return "Les membres intéressés par vos compétences seront notifiés et pourront rejoindre votre session."
        case .participantEmail: return "Email du participant"
        case .emailPlaceholder: return "ahmed@example.com"
        case .enterEmailError: return "Veuillez entrer un email."
        case .invalidEmailError: return "Format d'email invalide."
        case .participantExistsError: return "Ce participant est déjà ajouté."
        case .participantNotFoundError: return "Ce participant n'existe pas."
        case .loadSuggestionsError: return "Impossible de charger les suggestions."
        case .sessionMode: return "Mode de session"
        case .online: return "En ligne"
        case .inPerson: return "En personne"
        case .meetingLink: return "Lien de réunion (optionnel)"
        case .meetingLinkPlaceholder: return "Collez un lien Meet / Zoom"
        case .meetingLocation: return "Lieu de la rencontre"
        case .meetingLocationPlaceholder: return "Adresse du lieu de rencontre"
        case .selectOnMap: return "Sélectionner les coordonnées sur la carte"
        case .back: return "Retour"
        case .continueButton: return "Continuer"
        case .creatingButton: return "Création..."
        case .createSessionButton: return "Créer la session"
        case .titleRequiredError: return "Le titre est requis."
        case .skillRequiredError: return "Choisissez au moins une compétence."
        case .participantRequiredError: return "Ajoutez au moins un participant."
        case .locationRequiredError: return "Veuillez indiquer le lieu de la rencontre."
        case .userNotConnectedError: return "Utilisateur non connecté"
        case .creationError: return "Erreur lors de la création: %@"
        case .fetchAvailabilityError: return "Impossible de récupérer les disponibilités."
        
        case .profile: return "Profil"
        case .darkMode: return "Mode sombre"
        case .language: return "Langue"
        case .sessionsForYou: return "Sessions pour vous"
        case .referFriend: return "Référez un ami"
        case .shareProfile: return "Partager mon profil"
        case .myAnnouncements: return "Mes annonces"
        case .myPromos: return "Mes promos"
        case .settings: return "Paramètres"
        case .logout: return "Se déconnecter"
        case .notConnected: return "Vous n'êtes pas connecté."
        case .login: return "Se connecter"
        case .loadingProfile: return "Chargement du profil…"
        case .skillsTeaching: return "Compétences enseignées"
        case .skillsLearning: return "Compétences en apprentissage"
        case .badges: return "Badges obtenus"
        case .referralCode: return "Votre code de parrainage"
        case .remainingInvites: return "Invitations restantes"
        case .shareCode: return "Partager mon code"
        case .close: return "Fermer"
        case .sponsorship: return "Parrainage"
        case .cancel: return "Annuler"
        case .save: return "Enregistrer"
        case .error: return "Erreur"
        case .success: return "Succès"
        case .loading: return "Chargement..."
        case .sessions: return "Sessions"
        case .createSession: return "Créer une session"
        case .upcomingSessions: return "Sessions à venir"
        case .pastSessions: return "Sessions passées"
        case .messages: return "Messages"
        case .newMessage: return "Nouveau message"
        case .typeMessage: return "Tapez un message..."
        case .discover: return "Découvrir"
        case .noMoreUsers: return "Plus d'utilisateurs"
        case .itsAMatch: return "C'est un match !"
        case .sendMessage: return "Envoyer un message"
        case .keepSwiping: return "Continuer"
        case .tabDiscover: return "Découvrir"
        case .tabMessages: return "Messages"
        case .tabSessions: return "Sessions"
        case .tabProgress: return "Progrès"
        case .tabMap: return "Carte"
        case .email: return "Email"
        case .password: return "Mot de passe"
        case .forgotPassword: return "Mot de passe oublié ?"
        case .signUp: return "S'inscrire"
        case .signIn: return "Se connecter"
        case .dontHaveAccount: return "Pas encore de compte ?"
        case .alreadyHaveAccount: return "Déjà un compte ?"
        case .username: return "Nom d'utilisateur"
        case .fullName: return "Nom complet"
        case .confirmPassword: return "Confirmer le mot de passe"
        case .welcomeBack: return "Bon retour !"
        case .createAccount: return "Créer un compte"
        case .rememberMe: return "Se souvenir de moi"
        case .validateCode: return "Valider le code"
        case .optional: return "(optionnel)"
        case .orContinueWith: return "ou continuer avec"
        case .notifications: return "Notifications"
        case .markAllRead: return "Tout marquer comme lu"
        case .noNotifications: return "Aucune notification"
        case .profiles: return "Profils"
        case .announcements: return "Annonces"
        case .promos: return "Promos"
        case .noProfiles: return "Aucun profil disponible"
        case .reloadProfiles: return "Recharger les profils"
        case .noAnnouncements: return "Aucune annonce pour le moment."
        case .noPromos: return "Aucune promo pour le moment."
        case .searchAnnouncement: return "Rechercher une annonce"
        case .searchPromo: return "Rechercher une promo"
        case .youAndUserInterested: return "Vous et %@ vous êtes mutuellement intéressés"
        case .keepDiscovering: return "Continuer à découvrir"
        case .online: return "En ligne"
        case .teaches: return "Enseigne"
        case .learns: return "Apprend"
        case .filtersComingSoon: return "Filtres profils bientôt disponibles"
        case .sort: return "Trier"
        case .filters: return "Filtres"
        case .resetFilters: return "Réinitialiser filtres"
        case .withImageOnly: return "Avec image seulement"
        case .category: return "Catégorie"
        case .city: return "Ville"
        case .activeOnly: return "Actives seulement"
        case .minDiscount: return "Réduction min."
        case .until: return "Jusqu’au %@"
        case .mySessions: return "Mes Sessions"
        case .newSession: return "Nouvelle"
        case .upcoming: return "À venir"
        case .completed: return "Terminées"
        case .postponed: return "Reportées"
        case .thisWeek: return "Cette semaine"
        case .all: return "Toutes"
        case .sessionUntitled: return "Session sans titre"
        case .plan: return "Plan"
        case .postpone: return "Reporter"
        case .leaveReview: return "Laisser un avis"
        case .join: return "Rejoindre"
        case .proposeNewTime: return "Proposer un nouvel horaire"
        case .rescheduleProposal: return "Proposition de replanification"
        case .waitingForResponses: return "En attente des réponses des membres"
        case .youResponded: return "Vous avez répondu: %@"
        case .yes: return "Oui"
        case .no: return "Non"
        case .accept: return "Accepter"
        case .decline: return "Refuser"
        case .sendProposal: return "Envoyer la proposition"
        case .messageToMembers: return "Message aux membres"
        case .rescheduleSession: return "Replanifier %@"
        case .confirmPostpone: return "Reporter la session"
        case .areYouSurePostpone: return "Êtes-vous sûr de vouloir reporter cette session ?"
        case .date: return "Date"
        case .time: return "Heure"
        case .newDate: return "Nouvelle date"
        case .noConversations: return "Aucune conversation"
        case .chooseConversation: return "Choisissez une discussion"
        case .searchMentor: return "Rechercher un mentor"
        case .startConversation: return "Démarrer une conversation"
        case .replyTo: return "Réponse à"
        case .writeMessage: return "Écrivez votre message…"
        case .planSession: return "📅 Planifier une session"
        case .messageDeleted: return "🚫 Ce message a été supprimé"
        case .reply: return "Réponse"
        case .react: return "Réagir"
        case .delete: return "Supprimer"
        case .recipient: return "Destinataire"
        case .emailOrUsername: return "Email ou nom d'utilisateur"
        case .subject: return "Sujet (optionnel)"
        case .creating: return "Création en cours…"
        case .newConversation: return "Nouvelle discussion"
        case .create: return "Créer"
        case .searching: return "Recherche..."
        
        // Weekly Objectives
        case .weeklyObjectiveTitle: return "Objectif Hebdomadaire"
        case .noActiveObjective: return "Aucun objectif actif"
        case .createObjectivePrompt: return "Créez un objectif hebdomadaire pour suivre vos progrès et rester motivé."
        case .createObjective: return "Créer un objectif"
        case .dailyTasks: return "Tâches quotidiennes"
        case .todayTask: return "Tâche du jour"
        case .today: return "Aujourd'hui"
        case .tasksCompleted: return "tâches complétées"
        case .deleteObjective: return "Supprimer l'objectif"
        case .objectiveDetails: return "Détails de l'objectif"
        case .objectiveTitlePlaceholder: return "Ex: Apprendre Swift"
        case .targetHours: return "Heures cibles"
        case .dates: return "Dates"
        case .startDate: return "Date de début"
        case .endDate: return "Date de fin"
        case .dailyTasks7: return "Tâches quotidiennes (7 jours)"
        case .taskPlaceholder: return "Décrivez la tâche..."
        case .newObjective: return "Nouvel objectif"
        case .history: return "Historique"
        case .noHistory: return "Aucun objectif terminé"
        case .done: return "Terminé"
        }
    }
    
    private var englishValue: String {
        switch self {
        case .createSessionTitle: return "Create a New Session ⭐️"
        case .createSessionSubtitle: return "Share your skills with the community"
        case .stepSession: return "Session"
        case .stepPlanning: return "Planning"
        case .stepInvitations: return "Invitations"
        case .sessionTitle: return "Session Title"
        case .sessionTitlePlaceholder: return "Ex: iOS Workshop"
        case .description: return "Description"
        case .descriptionPlaceholder: return "Describe the session flow..."
        case .skill: return "Skill"
        case .addSkill: return "Add a Skill"
        case .customSkillPlaceholder: return "Custom Skill"
        case .sessionDate: return "Session Date"
        case .startTime: return "Start Time"
        case .duration: return "Duration"
        case .membersJoin: return "Other members will join"
        case .membersJoinSubtitle: return "Members interested in your skills will be notified and can join your session."
        case .participantEmail: return "Participant Email"
        case .emailPlaceholder: return "ahmed@example.com"
        case .enterEmailError: return "Please enter an email."
        case .invalidEmailError: return "Invalid email format."
        case .participantExistsError: return "This participant is already added."
        case .participantNotFoundError: return "This participant does not exist."
        case .loadSuggestionsError: return "Unable to load suggestions."
        case .sessionMode: return "Session Mode"
        case .online: return "Online"
        case .inPerson: return "In Person"
        case .meetingLink: return "Meeting Link (Optional)"
        case .meetingLinkPlaceholder: return "Paste a Meet / Zoom link"
        case .meetingLocation: return "Meeting Location"
        case .meetingLocationPlaceholder: return "Meeting address"
        case .selectOnMap: return "Select coordinates on map"
        case .back: return "Back"
        case .continueButton: return "Continue"
        case .creatingButton: return "Creating..."
        case .createSessionButton: return "Create Session"
        case .titleRequiredError: return "Title is required."
        case .skillRequiredError: return "Choose at least one skill."
        case .participantRequiredError: return "Add at least one participant."
        case .locationRequiredError: return "Please specify the meeting location."
        case .userNotConnectedError: return "User not logged in"
        case .creationError: return "Error creating session: %@"
        case .fetchAvailabilityError: return "Unable to fetch availability."
        
        case .profile: return "Profile"
        case .darkMode: return "Dark Mode"
        case .language: return "Language"
        case .sessionsForYou: return "Sessions for You"
        case .referFriend: return "Refer a Friend"
        case .shareProfile: return "Share My Profile"
        case .myAnnouncements: return "My Announcements"
        case .myPromos: return "My Promos"
        case .settings: return "Settings"
        case .logout: return "Log Out"
        case .notConnected: return "You are not logged in."
        case .login: return "Log In"
        case .loadingProfile: return "Loading profile…"
        case .skillsTeaching: return "Skills Teaching"
        case .skillsLearning: return "Skills Learning"
        case .badges: return "Badges Earned"
        case .referralCode: return "Your Referral Code"
        case .remainingInvites: return "Remaining Invites"
        case .shareCode: return "Share My Code"
        case .close: return "Close"
        case .sponsorship: return "Referral"
        case .cancel: return "Cancel"
        case .save: return "Save"
        case .error: return "Error"
        case .success: return "Success"
        case .loading: return "Loading..."
        case .sessions: return "Sessions"
        case .createSession: return "Create Session"
        case .upcomingSessions: return "Upcoming Sessions"
        case .pastSessions: return "Past Sessions"
        case .messages: return "Messages"
        case .newMessage: return "New Message"
        case .typeMessage: return "Type a message..."
        case .discover: return "Discover"
        case .noMoreUsers: return "No More Users"
        case .itsAMatch: return "It's a Match!"
        case .sendMessage: return "Send Message"
        case .keepSwiping: return "Keep Swiping"
        case .tabDiscover: return "Discover"
        case .tabMessages: return "Messages"
        case .tabSessions: return "Sessions"
        case .tabProgress: return "Progress"
        case .tabMap: return "Map"
        case .email: return "Email"
        case .password: return "Password"
        case .forgotPassword: return "Forgot Password?"
        case .signUp: return "Sign Up"
        case .signIn: return "Sign In"
        case .dontHaveAccount: return "Don't have an account?"
        case .alreadyHaveAccount: return "Already have an account?"
        case .username: return "Username"
        case .fullName: return "Full Name"
        case .confirmPassword: return "Confirm Password"
        case .welcomeBack: return "Welcome Back!"
        case .createAccount: return "Create Account"
        case .rememberMe: return "Remember me"
        case .validateCode: return "Validate Code"
        case .optional: return "(optional)"
        case .orContinueWith: return "or continue with"
        case .notifications: return "Notifications"
        case .markAllRead: return "Mark all as read"
        case .noNotifications: return "No notifications"
        case .profiles: return "Profiles"
        case .announcements: return "Announcements"
        case .promos: return "Promos"
        case .noProfiles: return "No profiles available"
        case .reloadProfiles: return "Reload profiles"
        case .noAnnouncements: return "No announcements yet."
        case .noPromos: return "No promos yet."
        case .searchAnnouncement: return "Search announcement"
        case .searchPromo: return "Search promo"
        case .youAndUserInterested: return "You and %@ are mutually interested"
        case .keepDiscovering: return "Keep discovering"
        case .online: return "Online"
        case .teaches: return "Teaches"
        case .learns: return "Learns"
        case .filtersComingSoon: return "Profile filters coming soon"
        case .sort: return "Sort"
        case .filters: return "Filters"
        case .resetFilters: return "Reset filters"
        case .withImageOnly: return "With image only"
        case .category: return "Category"
        case .city: return "City"
        case .activeOnly: return "Active only"
        case .minDiscount: return "Min discount"
        case .until: return "Until %@"
        case .mySessions: return "My Sessions"
        case .newSession: return "New"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        case .postponed: return "Postponed"
        case .thisWeek: return "This Week"
        case .all: return "All"
        case .sessionUntitled: return "Untitled Session"
        case .plan: return "Plan"
        case .postpone: return "Postpone"
        case .leaveReview: return "Leave Review"
        case .join: return "Join"
        case .proposeNewTime: return "Propose New Time"
        case .rescheduleProposal: return "Reschedule Proposal"
        case .waitingForResponses: return "Waiting for members' responses"
        case .youResponded: return "You responded: %@"
        case .yes: return "Yes"
        case .no: return "No"
        case .accept: return "Accept"
        case .decline: return "Decline"
        case .sendProposal: return "Send Proposal"
        case .messageToMembers: return "Message to members"
        case .rescheduleSession: return "Reschedule %@"
        case .confirmPostpone: return "Postpone Session"
        case .areYouSurePostpone: return "Are you sure you want to postpone this session?"
        case .date: return "Date"
        case .time: return "Time"
        case .newDate: return "New Date"
        case .noConversations: return "No conversations"
        case .chooseConversation: return "Choose a conversation"
        case .searchMentor: return "Search for a mentor"
        case .startConversation: return "Start a conversation"
        case .replyTo: return "Replying to"
        case .writeMessage: return "Write your message…"
        case .planSession: return "📅 Plan a session"
        case .messageDeleted: return "🚫 This message was deleted"
        case .reply: return "Reply"
        case .react: return "React"
        case .delete: return "Delete"
        case .recipient: return "Recipient"
        case .emailOrUsername: return "Email or username"
        case .subject: return "Subject (optional)"
        case .creating: return "Creating…"
        case .newConversation: return "New Conversation"
        case .create: return "Create"
        case .searching: return "Searching..."
        
        // Weekly Objectives
        case .weeklyObjectiveTitle: return "Weekly Objective"
        case .noActiveObjective: return "No active objective"
        case .createObjectivePrompt: return "Create a weekly objective to track your progress and stay motivated."
        case .createObjective: return "Create an objective"
        case .dailyTasks: return "Daily tasks"
        case .todayTask: return "Today's task"
        case .today: return "Today"
        case .tasksCompleted: return "tasks completed"
        case .deleteObjective: return "Delete objective"
        case .objectiveDetails: return "Objective Details"
        case .objectiveTitlePlaceholder: return "Ex: Learn Swift"
        case .targetHours: return "Target Hours"
        case .dates: return "Dates"
        case .startDate: return "Start Date"
        case .endDate: return "End Date"
        case .dailyTasks7: return "Daily Tasks (7 days)"
        case .taskPlaceholder: return "Describe the task..."
        case .newObjective: return "New Objective"
        case .history: return "History"
        case .noHistory: return "No completed objectives"
        case .done: return "Done"
        }
    }
    
    private var arabicValue: String {
        switch self {
        case .createSessionTitle: return "إنشاء جلسة جديدة ⭐️"
        case .createSessionSubtitle: return "شارك مهاراتك مع المجتمع"
        case .stepSession: return "الجلسة"
        case .stepPlanning: return "التخطيط"
        case .stepInvitations: return "الدعوات"
        case .sessionTitle: return "عنوان الجلسة"
        case .sessionTitlePlaceholder: return "مثال: ورشة عمل iOS"
        case .description: return "الوصف"
        case .descriptionPlaceholder: return "صف سير الجلسة..."
        case .skill: return "المهارة"
        case .addSkill: return "إضافة مهارة"
        case .customSkillPlaceholder: return "مهارة مخصصة"
        case .sessionDate: return "تاريخ الجلسة"
        case .startTime: return "وقت البدء"
        case .duration: return "المدة"
        case .membersJoin: return "سينضم أعضاء آخرون"
        case .membersJoinSubtitle: return "سيتم إخطار الأعضاء المهتمين بمهاراتك ويمكنهم الانضمام إلى جلستك."
        case .participantEmail: return "بريد المشارك"
        case .emailPlaceholder: return "ahmed@example.com"
        case .enterEmailError: return "الرجاء إدخال بريد إلكتروني."
        case .invalidEmailError: return "تنسيق البريد الإلكتروني غير صالح."
        case .participantExistsError: return "تمت إضافة هذا المشارك بالفعل."
        case .participantNotFoundError: return "هذا المشارك غير موجود."
        case .loadSuggestionsError: return "تعذر تحميل الاقتراحات."
        case .sessionMode: return "وضع الجلسة"
        case .online: return "عبر الإنترنت"
        case .inPerson: return "شخصياً"
        case .meetingLink: return "رابط الاجتماع (اختياري)"
        case .meetingLinkPlaceholder: return "الصق رابط Meet / Zoom"
        case .meetingLocation: return "مكان اللقاء"
        case .meetingLocationPlaceholder: return "عنوان اللقاء"
        case .selectOnMap: return "تحديد الإحداثيات على الخريطة"
        case .back: return "رجوع"
        case .continueButton: return "متابعة"
        case .creatingButton: return "جاري الإنشاء..."
        case .createSessionButton: return "إنشاء الجلسة"
        case .titleRequiredError: return "العنوان مطلوب."
        case .skillRequiredError: return "اختر مهارة واحدة على الأقل."
        case .participantRequiredError: return "أضف مشاركاً واحداً على الأقل."
        case .locationRequiredError: return "الرجاء تحديد مكان اللقاء."
        case .userNotConnectedError: return "المستخدم غير متصل"
        case .creationError: return "خطأ أثناء الإنشاء: %@"
        case .fetchAvailabilityError: return "تعذر جلب التوفر."
        
        case .profile: return "الملف الشخصي"
        case .darkMode: return "الوضع الداكن"
        case .language: return "اللغة"
        case .sessionsForYou: return "جلسات لك"
        case .referFriend: return "دعوة صديق"
        case .shareProfile: return "مشاركة ملفي"
        case .myAnnouncements: return "إعلاناتي"
        case .myPromos: return "عروضي"
        case .settings: return "الإعدادات"
        case .logout: return "تسجيل الخروج"
        case .notConnected: return "أنت غير متصل."
        case .login: return "تسجيل الدخول"
        case .loadingProfile: return "جاري تحميل الملف الشخصي..."
        case .skillsTeaching: return "المهارات التي أُدرّسها"
        case .skillsLearning: return "المهارات التي أتعلمها"
        case .badges: return "الشارات المكتسبة"
        case .referralCode: return "رمز الإحالة الخاص بك"
        case .remainingInvites: return "الدعوات المتبقية"
        case .shareCode: return "مشاركة الرمز"
        case .close: return "إغلاق"
        case .sponsorship: return "الإحالة"
        case .cancel: return "إلغاء"
        case .save: return "حفظ"
        case .error: return "خطأ"
        case .success: return "نجاح"
        case .loading: return "جاري التحميل..."
        case .sessions: return "الجلسات"
        case .createSession: return "إنشاء جلسة"
        case .upcomingSessions: return "الجلسات القادمة"
        case .pastSessions: return "الجلسات السابقة"
        case .messages: return "الرسائل"
        case .newMessage: return "رسالة جديدة"
        case .typeMessage: return "اكتب رسالة..."
        case .discover: return "اكتشف"
        case .noMoreUsers: return "لا مزيد من المستخدمين"
        case .itsAMatch: return "إنه تطابق!"
        case .sendMessage: return "إرسال رسالة"
        case .keepSwiping: return "استمر"
        case .tabDiscover: return "اكتشف"
        case .tabMessages: return "الرسائل"
        case .tabSessions: return "الجلسات"
        case .tabProgress: return "التقدم"
        case .tabMap: return "الخريطة"
        case .email: return "البريد الإلكتروني"
        case .password: return "كلمة المرور"
        case .forgotPassword: return "نسيت كلمة المرور؟"
        case .signUp: return "إنشاء حساب"
        case .signIn: return "تسجيل الدخول"
        case .dontHaveAccount: return "ليس لديك حساب؟"
        case .alreadyHaveAccount: return "لديك حساب بالفعل؟"
        case .username: return "اسم المستخدم"
        case .fullName: return "الاسم الكامل"
        case .confirmPassword: return "تأكيد كلمة المرور"
        case .welcomeBack: return "مرحباً بعودتك!"
        case .createAccount: return "إنشاء حساب جديد"
        case .rememberMe: return "تذكرني"
        case .validateCode: return "التحقق من الرمز"
        case .optional: return "(اختياري)"
        case .orContinueWith: return "أو المتابعة باستخدام"
        case .notifications: return "الإشعارات"
        case .markAllRead: return "تحديد الكل كمقروء"
        case .noNotifications: return "لا توجد إشعارات"
        case .profiles: return "ملفات شخصية"
        case .announcements: return "إعلانات"
        case .promos: return "عروض"
        case .noProfiles: return "لا توجد ملفات شخصية متاحة"
        case .reloadProfiles: return "إعادة تحميل الملفات"
        case .noAnnouncements: return "لا توجد إعلانات حتى الآن."
        case .noPromos: return "لا توجد عروض حتى الآن."
        case .searchAnnouncement: return "البحث عن إعلان"
        case .searchPromo: return "البحث عن عرض"
        case .youAndUserInterested: return "أنت و %@ مهتمان ببعضكما"
        case .keepDiscovering: return "استمر في الاكتشاف"
        case .online: return "متصل"
        case .teaches: return "يُدرّس"
        case .learns: return "يتعلم"
        case .filtersComingSoon: return "فلاتر الملفات الشخصية قريباً"
        case .sort: return "فرز"
        case .filters: return "تصفية"
        case .resetFilters: return "إعادة تعيين الفلاتر"
        case .withImageOnly: return "مع صورة فقط"
        case .category: return "الفئة"
        case .city: return "المدينة"
        case .activeOnly: return "النشطة فقط"
        case .minDiscount: return "الحد الأدنى للخصم"
        case .until: return "حتى %@"
        case .mySessions: return "جلساتي"
        case .newSession: return "جديدة"
        case .upcoming: return "القادمة"
        case .completed: return "المكتملة"
        case .postponed: return "المؤجلة"
        case .thisWeek: return "هذا الأسبوع"
        case .all: return "الكل"
        case .sessionUntitled: return "جلسة بدون عنوان"
        case .plan: return "الخطة"
        case .postpone: return "تأجيل"
        case .leaveReview: return "ترك تقييم"
        case .join: return "انضمام"
        case .proposeNewTime: return "اقتراح وقت جديد"
        case .rescheduleProposal: return "اقتراح إعادة جدولة"
        case .waitingForResponses: return "في انتظار ردود الأعضاء"
        case .youResponded: return "لقد أجبت: %@"
        case .yes: return "نعم"
        case .no: return "لا"
        case .accept: return "قبول"
        case .decline: return "رفض"
        case .sendProposal: return "إرسال الاقتراح"
        case .messageToMembers: return "رسالة للأعضاء"
        case .rescheduleSession: return "إعادة جدولة %@"
        case .confirmPostpone: return "تأجيل الجلسة"
        case .areYouSurePostpone: return "هل أنت متأكد أنك تريد تأجيل هذه الجلسة؟"
        case .date: return "التاريخ"
        case .time: return "الوقت"
        case .newDate: return "تاريخ جديد"
        case .noConversations: return "لا توجد محادثات"
        case .chooseConversation: return "اختر محادثة"
        case .searchMentor: return "البحث عن مرشد"
        case .startConversation: return "بدء محادثة"
        case .replyTo: return "الرد على"
        case .writeMessage: return "اكتب رسالتك..."
        case .planSession: return "📅 تخطيط جلسة"
        case .messageDeleted: return "🚫 تم حذف هذه الرسالة"
        case .reply: return "رد"
        case .react: return "تفاعل"
        case .delete: return "حذف"
        case .recipient: return "المستلم"
        case .emailOrUsername: return "البريد الإلكتروني أو اسم المستخدم"
        case .subject: return "الموضوع (اختياري)"
        case .creating: return "جاري الإنشاء..."
        case .newConversation: return "محادثة جديدة"
        case .create: return "إنشاء"
        case .searching: return "جاري البحث..."
        
        // Weekly Objectives
        case .weeklyObjectiveTitle: return "الهدف الأسبوعي"
        case .noActiveObjective: return "لا يوجد هدف نشط"
        case .createObjectivePrompt: return "أنشئ هدفًا أسبوعيًا لتتبع تقدمك والبقاء متحمسًا."
        case .createObjective: return "إنشاء هدف"
        case .dailyTasks: return "المهام اليومية"
        case .todayTask: return "مهمة اليوم"
        case .today: return "اليوم"
        case .tasksCompleted: return "مهام مكتملة"
        case .deleteObjective: return "حذف الهدف"
        case .objectiveDetails: return "تفاصيل الهدف"
        case .objectiveTitlePlaceholder: return "مثال: تعلم Swift"
        case .targetHours: return "الساعات المستهدفة"
        case .dates: return "التواريخ"
        case .startDate: return "تاريخ البدء"
        case .endDate: return "تاريخ الانتهاء"
        case .dailyTasks7: return "المهام اليومية (7 أيام)"
        case .taskPlaceholder: return "صف المهمة..."
        case .newObjective: return "هدف جديد"
        case .history: return "السجل"
        case .noHistory: return "لا توجد أهداف مكتملة"
        case .done: return "تم"
        }
    }
}

// MARK: - View Extension for Localization
extension View {
    func localized(_ key: LocalizedKey) -> String {
        LocalizationManager.shared.localized(key)
    }
}
