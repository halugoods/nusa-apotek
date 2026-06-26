#!/usr/bin/env python3
"""Insert 45 new domains into DOMAIN_PACKS, DOMAIN_KEYWORDS, and domainHints in app.js."""

import re

JS_FILE = r'C:\Users\ertyui\prdkit\docs\app.js'

with open(JS_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# ============================================================
# All 45 new DOMAIN_PACKS entries
# ============================================================

new_domains_packs = r'''
  pharmacy: {
    name: 'Pharmacy / Apotek',
    actors: ['Pharmacist', 'Customer', 'Admin'],
    entities: {
      Medicine: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', price: 'Float', requiresPrescription: 'Boolean @default(false)', expiryDate: 'DateTime?', stock: 'Int @default(0)', minStock: 'Int @default(10)' },
        indexes: ['sku', 'category', 'stock'],
        relations: { hasMany: ['Prescription', 'Stock'] }
      },
      Prescription: {
        fields: { customerId: 'string', pharmacistId: 'string', medicineId: 'string', dosage: 'string', quantity: 'Int', status: 'RxStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { RxStatus: ['PENDING', 'FILLED', 'DISPENSED', 'CANCELLED'] },
        indexes: ['customerId', 'status'],
        relations: { belongsTo: ['Customer', 'Medicine'], hasMany: ['Sale'] }
      },
      Stock: {
        fields: { medicineId: 'string', batchNumber: 'string', quantity: 'Int', expiryDate: 'DateTime?', receivedAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'batchNumber'],
        relations: { belongsTo: ['Medicine', 'Supplier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Sale: {
        fields: { prescriptionId: 'string?', customerId: 'string', medicineId: 'string', quantity: 'Int', totalPrice: 'Float', paymentMethod: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['customerId', 'soldAt'],
        relations: { belongsTo: ['Medicine', 'Customer'] }
      },
    },
    flows: ['Pharmacist checks stock levels for medicines', 'Customer brings prescription — pharmacist validates', 'Pharmacist dispenses medicine — stock decremented', 'Sale recorded — payment processed', 'Admin reconciles daily sales and stock adjustments'],
    endpoints: ['GET    /api/medicines                        ?category=&requiresPrescription=&search=&page=&limit=', 'POST   /api/medicines                        { name, sku, category, price, requiresPrescription, minStock }', 'GET    /api/prescriptions                     ?status=&customerId=&page=&limit=', 'POST   /api/prescriptions                     { customerId, medicineId, dosage, quantity }', 'PATCH  /api/prescriptions/:id/status           { status }', 'POST   /api/sales                             { prescriptionId?, customerId, medicineId, quantity, totalPrice, paymentMethod }', 'GET    /api/dashboard/pharmacy-summary'],
    metrics: ['Daily revenue', 'Prescriptions filled', 'Stock expiring soon', 'Medicine turnover rate', 'Customer visits'],
    genericFeatures: ['Manajemen Obat', 'Resep Obat', 'Inventory Stok', 'Penjualan', 'Laporan Apotek'],
  },

  laboratory: {
    name: 'Laboratory / Lab Kesehatan',
    actors: ['LabTech', 'Patient', 'Doctor', 'Admin'],
    entities: {
      Test: {
        fields: { name: 'string @unique', category: 'string', description: 'string?', price: 'Float', preparation: 'string?', turnaroundHours: 'Int', isActive: 'Boolean @default(true)' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Sample', 'Result'] }
      },
      Sample: {
        fields: { patientId: 'string', testId: 'string', labTechId: 'string', collectionDate: 'DateTime', sampleType: 'string', status: 'SampleStatus @default(COLLECTED)', notes: 'string?', receivedAt: 'DateTime?' },
        enums: { SampleStatus: ['COLLECTED', 'RECEIVED', 'PROCESSING', 'ANALYZED', 'REJECTED'] },
        indexes: ['patientId', 'testId', 'status'],
        relations: { belongsTo: ['Patient', 'Test', 'LabTech'] }
      },
      Result: {
        fields: { sampleId: 'string', testId: 'string', value: 'string', unit: 'string?', referenceRange: 'string?', isAbnormal: 'Boolean @default(false)', interpretation: 'string?', verifiedBy: 'string?', verifiedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['sampleId', 'testId', 'isAbnormal'],
        relations: { belongsTo: ['Sample', 'Test'] }
      },
      Patient: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', dateOfBirth: 'DateTime?', gender: 'string?', address: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Sample'] }
      },
      Appointment: {
        fields: { patientId: 'string', testId: 'string', appointmentDate: 'DateTime', status: 'ApptStatus @default(SCHEDULED)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['SCHEDULED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['patientId', 'appointmentDate', 'status'],
        relations: { belongsTo: ['Patient', 'Test'] }
      },
    },
    flows: ['Patient registers for lab test — selects test panel', 'LabTech collects sample from patient at scheduled time', 'Sample is processed and analyzed in the lab', 'Results are verified and published for doctor review', 'Doctor interprets results and shares with patient'],
    endpoints: ['GET    /api/tests                            ?category=&isActive=&search=', 'POST   /api/appointments                     { patientId, testId, appointmentDate }', 'POST   /api/samples                          { patientId, testId, labTechId, sampleType }', 'GET    /api/samples                          ?patientId=&status=&dateFrom=', 'PATCH  /api/samples/:id/status                { status }', 'POST   /api/results                          { sampleId, testId, value, unit?, referenceRange? }', 'GET    /api/results/:patientId', 'GET    /api/dashboard/lab-summary'],
    metrics: ['Tests per day', 'Sample processing time', 'Abnormal result rate', 'Patient turnaround time', 'Revenue per test'],
    genericFeatures: ['Manajemen Test Lab', 'Sample Tracking', 'Hasil & Analisa', 'Jadwal Appointment', 'Laporan Lab'],
  },

  telemedicine: {
    name: 'Telemedicine / Konsultasi Online',
    actors: ['Doctor', 'Patient', 'Admin'],
    entities: {
      Consultation: {
        fields: { patientId: 'string', doctorId: 'string', appointmentId: 'string', startTime: 'DateTime', endTime: 'DateTime?', status: 'ConsStatus @default(SCHEDULED)', type: 'string @default("VIDEO")', notes: 'string?', summary: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ConsStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'MISSED'] },
        indexes: ['patientId', 'doctorId', 'startTime', 'status'],
        relations: { belongsTo: ['Patient', 'Doctor', 'Appointment'] }
      },
      Prescription: {
        fields: { consultationId: 'string', medicine: 'string', dosage: 'string', frequency: 'string', duration: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['consultationId'],
        relations: { belongsTo: ['Consultation'] }
      },
      Appointment: {
        fields: { patientId: 'string', doctorId: 'string', scheduledAt: 'DateTime', duration: 'Int @default(30)', status: 'ApptStatus @default(PENDING)', reason: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['patientId', 'doctorId', 'scheduledAt', 'status'],
        relations: { belongsTo: ['Patient', 'Doctor'] }
      },
      Payment: {
        fields: { consultationId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['consultationId', 'status'],
        relations: { belongsTo: ['Consultation'] }
      },
      MedicalRecord: {
        fields: { patientId: 'string', consultationId: 'string', diagnosis: 'string?', symptoms: 'string?', treatment: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['patientId'],
        relations: { belongsTo: ['Patient', 'Consultation'] }
      },
    },
    flows: ['Patient books an appointment with a doctor online', 'Doctor accepts consultation — video/chat session begins', 'Doctor diagnoses patient and writes prescription', 'Prescription sent to patient — payment processed', 'Follow-up scheduled if needed — medical record updated'],
    endpoints: ['GET    /api/doctors                          ?specialty=&isAvailable=&rating=', 'POST   /api/appointments                     { patientId, doctorId, scheduledAt, reason }', 'GET    /api/appointments                     ?patientId=&status=&page=&limit=', 'POST   /api/consultations                    { patientId, doctorId, appointmentId, type }', 'PATCH  /api/consultations/:id/status          { status }', 'POST   /api/prescriptions                    { consultationId, medicine, dosage, frequency, duration }', 'POST   /api/payments                         { consultationId, amount, method }', 'GET    /api/medical-records/:patientId'],
    metrics: ['Consultations per day', 'Average response time', 'Patient satisfaction', 'Prescription rate', 'Revenue per consultation'],
    genericFeatures: ['Konsultasi Online', 'Jadwal Dokter', 'Resep Digital', 'Pembayaran', 'Rekam Medis'],
  },

  tutoring: {
    name: 'Tutoring / Bimbel',
    actors: ['Tutor', 'Student', 'Parent', 'Admin'],
    entities: {
      Session: {
        fields: { tutorId: 'string', studentId: 'string', subjectId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'SessStatus @default(SCHEDULED)', topic: 'string?', notes: 'string?', rating: 'Int?', createdAt: 'DateTime @default(now())' },
        enums: { SessStatus: ['SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['tutorId', 'studentId', 'date', 'status'],
        relations: { belongsTo: ['Tutor', 'Student', 'Subject'] }
      },
      Subject: {
        fields: { name: 'string @unique', level: 'string', description: 'string?', pricePerHour: 'Float', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Session'] }
      },
      Student: {
        fields: { name: 'string', parentId: 'string?', email: 'string?', phone: 'string?', grade: 'string?', school: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Parent'], hasMany: ['Session'] }
      },
      Payment: {
        fields: { sessionId: 'string?', studentId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', period: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['studentId', 'status'],
        relations: { belongsTo: ['Student'] }
      },
      Schedule: {
        fields: { tutorId: 'string', dayOfWeek: 'string', startTime: 'string', endTime: 'string', isRecurring: 'Boolean @default(true)' },
        indexes: ['tutorId', 'dayOfWeek'],
        relations: { belongsTo: ['Tutor'] }
      },
    },
    flows: ['Parent registers student and selects subjects', 'Student books tutoring session with a tutor', 'Tutor conducts the session — teaches and assigns homework', 'Student completes homework — tutor reviews and gives feedback', 'Admin generates monthly report and processes payments'],
    endpoints: ['GET    /api/subjects                         ?level=&isActive=', 'POST   /api/sessions                         { tutorId, studentId, subjectId, date, startTime, endTime }', 'GET    /api/sessions                         ?studentId=&tutorId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/sessions/:id/status               { status }', 'POST   /api/homework                         { sessionId, title, description, dueDate }', 'POST   /api/payments                         { studentId, amount, method, period }', 'GET    /api/dashboard/tutoring-summary'],
    metrics: ['Sessions per week', 'Student satisfaction', 'Tutor utilization rate', 'Revenue per month', 'Homework completion rate'],
    genericFeatures: ['Manajemen Bimbel', 'Jadwal Tutor', 'Sesi Belajar', 'Pembayaran SPP', 'Laporan Progress'],
  },

  bootcamp: {
    name: 'Bootcamp / Pelatihan Intensif',
    actors: ['Mentor', 'Student', 'Admin'],
    entities: {
      Program: {
        fields: { name: 'string @unique', description: 'string?', duration: 'string', price: 'Float', maxStudents: 'Int', startDate: 'DateTime', endDate: 'DateTime', status: 'ProgStatus @default(DRAFT)', curriculum: 'string (JSON)?', isActive: 'Boolean @default(true)' },
        enums: { ProgStatus: ['DRAFT', 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['status', 'startDate'],
        relations: { hasMany: ['Module', 'Submission'] }
      },
      Module: {
        fields: { programId: 'string', title: 'string', description: 'string?', order: 'Int', duration: 'Int', materials: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        indexes: ['programId', 'order'],
        relations: { belongsTo: ['Program'], hasMany: ['Assignment'] }
      },
      Assignment: {
        fields: { moduleId: 'string', title: 'string', description: 'string?', dueDate: 'DateTime', maxScore: 'Int @default(100)', type: 'string @default("CODING")' },
        relations: { belongsTo: ['Module'], hasMany: ['Submission'] }
      },
      Submission: {
        fields: { assignmentId: 'string', studentId: 'string', fileUrl: 'string?', notes: 'string?', score: 'Int?', feedback: 'string?', status: 'SubStatus @default(PENDING)', submittedAt: 'DateTime @default(now())', gradedAt: 'DateTime?' },
        enums: { SubStatus: ['PENDING', 'SUBMITTED', 'GRADED', 'RESUBMIT'] },
        indexes: ['assignmentId', 'studentId', 'status'],
        relations: { belongsTo: ['Assignment', 'Student'] }
      },
      Review: {
        fields: { submissionId: 'string', mentorId: 'string', score: 'Int', feedback: 'string?', reviewedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Submission', 'Mentor'] }
      },
    },
    flows: ['Student enrolls in a bootcamp program', 'Student progresses through modules sequentially', 'Student works on projects and assignments', 'Mentor reviews submissions and provides feedback', 'Student graduates upon completing all requirements'],
    endpoints: ['GET    /api/programs                         ?status=&isActive=&page=&limit=', 'POST   /api/programs                         { name, description, duration, price, maxStudents, startDate, endDate }', 'GET    /api/modules/:programId', 'POST   /api/assignments                      { moduleId, title, description, dueDate, maxScore }', 'POST   /api/submissions                      { assignmentId, studentId, fileUrl?, notes? }', 'PATCH  /api/submissions/:id/grade             { score, feedback }', 'GET    /api/dashboard/bootcamp-summary'],
    metrics: ['Enrollment rate', 'Module completion %', 'Graduation rate', 'Average score', 'Student satisfaction'],
    genericFeatures: ['Manajemen Program', 'Modul & Assignment', 'Submission Grading', 'Progress Student', 'Graduation'],
  },

  school_management: {
    name: 'School Management / Manajemen Sekolah',
    actors: ['Teacher', 'Student', 'Parent', 'Admin'],
    entities: {
      Class: {
        fields: { name: 'string', grade: 'string', section: 'string?', academicYear: 'string', teacherId: 'string', room: 'string?', capacity: 'Int @default(30)', createdAt: 'DateTime @default(now())' },
        indexes: ['grade', 'teacherId', 'academicYear'],
        relations: { belongsTo: ['Teacher'], hasMany: ['Student', 'Schedule'] }
      },
      Student: {
        fields: { name: 'string', nisn: 'string @unique', classId: 'string', dateOfBirth: 'DateTime?', gender: 'string?', address: 'string?', parentPhone: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['nisn', 'classId', 'status'],
        relations: { belongsTo: ['Class'], hasMany: ['Grade', 'Attendance'] }
      },
      Teacher: {
        fields: { name: 'string', nip: 'string @unique', email: 'string?', phone: 'string?', specialization: 'string?', isActive: 'Boolean @default(true)' },
        hasMany: ['Class', 'Schedule']
      },
      Schedule: {
        fields: { classId: 'string', teacherId: 'string', subject: 'string', dayOfWeek: 'string', startTime: 'string', endTime: 'string', room: 'string?' },
        indexes: ['classId', 'teacherId', 'dayOfWeek'],
        relations: { belongsTo: ['Class', 'Teacher'] }
      },
      Grade: {
        fields: { studentId: 'string', classId: 'string', subject: 'string', semester: 'string', score: 'Float', grade: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['studentId', 'classId', 'semester'],
        relations: { belongsTo: ['Student', 'Class'] }
      },
      Attendance: {
        fields: { studentId: 'string', classId: 'string', date: 'DateTime', status: 'AttStatus @default(PRESENT)', notes: 'string?', recordedBy: 'string' },
        enums: { AttStatus: ['PRESENT', 'ABSENT', 'SICK', 'PERMIT', 'LATE'] },
        indexes: ['studentId', 'classId', 'date'],
        relations: { belongsTo: ['Student', 'Class'] }
      },
    },
    flows: ['Admin enrolls new students and assigns to classes', 'Teacher creates class schedule and records attendance', 'Teacher teaches lessons and assigns grades', 'Students receive report cards each semester', 'Admin generates academic reports and statistics'],
    endpoints: ['GET    /api/classes                          ?grade=&academicYear=&teacherId=', 'POST   /api/students                         { name, nisn, classId, dateOfBirth?, address? }', 'GET    /api/students                         ?classId=&status=&search=&page=&limit=', 'POST   /api/attendance                       { studentId, classId, date, status, notes? }', 'POST   /api/grades                           { studentId, classId, subject, semester, score }', 'GET    /api/grades/:studentId                 ?semester=', 'GET    /api/dashboard/school-summary'],
    metrics: ['Total students', 'Attendance rate', 'Average grade per class', 'Teacher workload', 'Graduation rate'],
    genericFeatures: ['Manajemen Kelas', 'Data Siswa', 'Absensi', 'Penilaian & Rapor', 'Jadwal Pelajaran'],
  },

  lms: {
    name: 'LMS / Learning Management',
    actors: ['Instructor', 'Learner', 'Admin'],
    entities: {
      Course: {
        fields: { title: 'string', description: 'string?', category: 'string?', level: 'string @default("BEGINNER")', price: 'Float @default(0)', thumbnail: 'string?', status: 'CourseStatus @default(DRAFT)', instructorId: 'string', duration: 'Int', createdAt: 'DateTime @default(now())' },
        enums: { CourseStatus: ['DRAFT', 'PUBLISHED', 'ARCHIVED'] },
        indexes: ['instructorId', 'category', 'status'],
        relations: { belongsTo: ['Instructor'], hasMany: ['Lesson', 'Quiz'] }
      },
      Lesson: {
        fields: { courseId: 'string', title: 'string', content: 'string (HTML)?', videoUrl: 'string?', order: 'Int', duration: 'Int', isFree: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['courseId', 'order'],
        relations: { belongsTo: ['Course'] }
      },
      Quiz: {
        fields: { courseId: 'string', title: 'string', description: 'string?', passingScore: 'Int @default(70)', maxAttempts: 'Int @default(3)', timeLimit: 'Int?', status: 'string @default("ACTIVE")' },
        indexes: ['courseId'],
        relations: { belongsTo: ['Course'], hasMany: ['Progress'] }
      },
      Progress: {
        fields: { learnerId: 'string', courseId: 'string', lessonId: 'string?', quizId: 'string?', score: 'Int?', completed: 'Boolean @default(false)', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['learnerId', 'courseId', 'completed'],
        relations: { belongsTo: ['Learner', 'Course'] }
      },
      Certificate: {
        fields: { learnerId: 'string', courseId: 'string', certificateNumber: 'string @unique', issuedAt: 'DateTime @default(now())', expiresAt: 'DateTime?', metadata: 'string (JSON)?' },
        indexes: ['learnerId', 'courseId'],
        relations: { belongsTo: ['Learner', 'Course'] }
      },
    },
    flows: ['Instructor creates and publishes a course with lessons', 'Learner browses courses and enrolls', 'Learner progresses through lessons sequentially', 'Learner takes quizzes to assess understanding', 'Learner earns certificate upon course completion'],
    endpoints: ['GET    /api/courses                          ?category=&level=&status=&search=&page=&limit=', 'POST   /api/courses                          { title, description?, category?, level, price, instructorId }', 'GET    /api/courses/:id/lessons', 'POST   /api/lessons                          { courseId, title, content?, videoUrl?, order, duration }', 'POST   /api/quizzes                          { courseId, title, description?, passingScore, maxAttempts }', 'POST   /api/progress                         { learnerId, courseId, lessonId?, quizId?, score? }', 'POST   /api/certificates                     { learnerId, courseId }', 'GET    /api/dashboard/lms-summary'],
    metrics: ['Total enrollments', 'Course completion rate', 'Average quiz score', 'Certificate issued', 'Revenue per course'],
    genericFeatures: ['Course Management', 'Lesson Delivery', 'Quiz & Assessment', 'Progress Tracking', 'Certification'],
  },

  personal_finance: {
    name: 'Personal Finance / Keuangan Pribadi',
    actors: ['User', 'Admin'],
    entities: {
      Transaction: {
        fields: { userId: 'string', categoryId: 'string', type: 'string @default("EXPENSE")', amount: 'Float', description: 'string?', date: 'DateTime', isRecurring: 'Boolean @default(false)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'categoryId', 'date', 'type'],
        relations: { belongsTo: ['User', 'Category'] }
      },
      Category: {
        fields: { name: 'string', type: 'string', icon: 'string?', color: 'string?', budget: 'Float?', isActive: 'Boolean @default(true)' },
        indexes: ['type', 'isActive'],
        relations: { hasMany: ['Transaction'] }
      },
      Budget: {
        fields: { userId: 'string', categoryId: 'string', amount: 'Float', period: 'string @default("MONTHLY")', startDate: 'DateTime', endDate: 'DateTime?', spent: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'categoryId', 'period'],
        relations: { belongsTo: ['User', 'Category'] }
      },
      Account: {
        fields: { userId: 'string', name: 'string', type: 'string @default("CASH")', balance: 'Float @default(0)', currency: 'string @default("IDR")', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'type'],
        relations: { belongsTo: ['User'] }
      },
      Goal: {
        fields: { userId: 'string', name: 'string', targetAmount: 'Float', currentAmount: 'Float @default(0)', deadline: 'DateTime?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['userId', 'status'],
        relations: { belongsTo: ['User'] }
      },
    },
    flows: ['User records daily income and expenses', 'System categorizes transactions automatically', 'User sets budgets per category for the month', 'User tracks spending against budgets', 'System generates monthly financial reports'],
    endpoints: ['GET    /api/transactions                      ?type=&categoryId=&dateFrom=&dateTo=&page=&limit=', 'POST   /api/transactions                      { userId, categoryId, type, amount, description?, date }', 'GET    /api/categories                        ?type=&isActive=', 'POST   /api/budgets                           { userId, categoryId, amount, period }', 'POST   /api/goals                            { userId, name, targetAmount, deadline? }', 'GET    /api/dashboard/finance-summary', 'GET    /api/reports/monthly                   ?month=&year='],
    metrics: ['Monthly savings rate', 'Budget adherence %', 'Net worth growth', 'Category spending breakdown', 'Goal progress %'],
    genericFeatures: ['Pencatatan Transaksi', 'Kategori & Budget', 'Laporan Keuangan', 'Target Tabungan', 'Dashboard Keuangan'],
  },

  cooperative: {
    name: 'Cooperative / Koperasi',
    actors: ['Member', 'Treasurer', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', memberNumber: 'string @unique', phone: 'string', email: 'string?', address: 'string?', joinDate: 'DateTime', status: 'string @default("ACTIVE")', savingsBalance: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['memberNumber', 'status'],
        relations: { hasMany: ['Savings', 'Loan'] }
      },
      Savings: {
        fields: { memberId: 'string', amount: 'Float', type: 'SavingsType @default(MANDATORY)', depositDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { SavingsType: ['MANDATORY', 'VOLUNTARY', 'SPECIAL'] },
        indexes: ['memberId', 'depositDate'],
        relations: { belongsTo: ['Member'] }
      },
      Loan: {
        fields: { memberId: 'string', amount: 'Float', interestRate: 'Float', tenor: 'Int', remainingBalance: 'Float', status: 'LoanStatus @default(PENDING)', purpose: 'string?', approvedBy: 'string?', approvedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { LoanStatus: ['PENDING', 'APPROVED', 'ACTIVE', 'PAID', 'DEFAULTED'] },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'], hasMany: ['Installment'] }
      },
      Installment: {
        fields: { loanId: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['loanId', 'status', 'dueDate'],
        relations: { belongsTo: ['Loan'] }
      },
      Dividend: {
        fields: { memberId: 'string', year: 'Int', amount: 'Float', status: 'string @default("PENDING")', distributedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'year'],
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['New member registers and starts saving', 'Member applies for a loan with amount and tenor', 'Treasurer reviews and approves loan', 'Member repays loan in monthly installments', 'Annual dividend calculated and distributed to members'],
    endpoints: ['GET    /api/members                          ?status=&search=&page=&limit=', 'POST   /api/members                          { name, phone, email?, address? }', 'POST   /api/savings                          { memberId, amount, type }', 'POST   /api/loans                            { memberId, amount, interestRate, tenor, purpose }', 'GET    /api/loans                            ?status=&memberId=&page=&limit=', 'POST   /api/installments                     { loanId, amount }', 'POST   /api/dividends                        { memberId, year, amount }', 'GET    /api/dashboard/cooperative-summary'],
    metrics: ['Total savings', 'Loan disbursed', 'Repayment rate', 'Active members', 'Dividend payout'],
    genericFeatures: ['Manajemen Anggota', 'Simpanan', 'Pinjaman & Angsuran', 'SHU / Dividen', 'Laporan Koperasi'],
  },

  insurance: {
    name: 'Insurance / Asuransi',
    actors: ['Client', 'Agent', 'Adjuster', 'Admin'],
    entities: {
      Policy: {
        fields: { policyNumber: 'string @unique', clientId: 'string', agentId: 'string', type: 'PolicyType', premium: 'Float', coverageAmount: 'Float', startDate: 'DateTime', endDate: 'DateTime', status: 'PolStatus @default(ACTIVE)', terms: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        enums: { PolicyType: ['HEALTH', 'LIFE', 'AUTO', 'HOME', 'TRAVEL', 'BUSINESS'], PolStatus: ['ACTIVE', 'EXPIRED', 'CANCELLED', 'LAPSED'] },
        indexes: ['policyNumber', 'clientId', 'agentId', 'status'],
        relations: { belongsTo: ['Client', 'Agent'], hasMany: ['Premium', 'Claim'] }
      },
      Premium: {
        fields: { policyId: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', paymentMethod: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['policyId', 'dueDate', 'status'],
        relations: { belongsTo: ['Policy'] }
      },
      Claim: {
        fields: { policyId: 'string', clientId: 'string', adjusterId: 'string?', incidentDate: 'DateTime', amount: 'Float', description: 'string', status: 'ClaimStatus @default(SUBMITTED)', documents: 'string (JSON)?', approvedAmount: 'Float?', settledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { ClaimStatus: ['SUBMITTED', 'IN_REVIEW', 'APPROVED', 'REJECTED', 'SETTLED'] },
        indexes: ['policyId', 'clientId', 'status'],
        relations: { belongsTo: ['Policy', 'Client'] }
      },
      Payment: {
        fields: { policyId: 'string?', claimId: 'string?', amount: 'Float', type: 'string', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Policy'] }
      },
      Client: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', dateOfBirth: 'DateTime?', address: 'string?', idNumber: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Policy', 'Claim'] }
      },
    },
    flows: ['Client requests a quote — agent assesses risk', 'Agent submits application — policy is issued', 'Client pays premium — policy becomes active', 'Client files a claim — adjuster investigates', 'Claim is approved or rejected — settlement processed'],
    endpoints: ['GET    /api/policies                         ?status=&type=&clientId=&agentId=&page=&limit=', 'POST   /api/policies                         { clientId, agentId, type, premium, coverageAmount, startDate, endDate }', 'GET    /api/premiums                          ?policyId=&status=&dueDate=', 'PATCH  /api/premiums/:id/pay                  { paidAt, paymentMethod }', 'POST   /api/claims                            { policyId, clientId, incidentDate, amount, description }', 'GET    /api/claims                            ?status=&policyId=&page=&limit=', 'PATCH  /api/claims/:id/status                 { status, approvedAmount? }', 'GET    /api/dashboard/insurance-summary'],
    metrics: ['Active policies', 'Premium collection rate', 'Claim ratio', 'Average settlement time', 'Policy renewal rate'],
    genericFeatures: ['Manajemen Polis', 'Premi & Pembayaran', 'Klaim & Adjuster', 'Underwriting', 'Laporan Asuransi'],
  },

  warehouse: {
    name: 'Warehouse / Gudang',
    actors: ['Manager', 'Staff', 'Admin'],
    entities: {
      Product: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', unit: 'string', weight: 'Float?', dimensions: 'string?', isHazardous: 'Boolean @default(false)', minStock: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category'],
        relations: { hasMany: ['Bin', 'StockMovement'] }
      },
      Bin: {
        fields: { code: 'string @unique', zone: 'string', aisle: 'string', rack: 'string', level: 'string', capacity: 'Int', currentLoad: 'Int @default(0)', productId: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'zone', 'productId'],
        relations: { belongsTo: ['Product'] }
      },
      StockMovement: {
        fields: { productId: 'string', binId: 'string?', type: 'MovementType', quantity: 'Int', referenceNumber: 'string?', staffId: 'string', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { MovementType: ['INBOUND', 'OUTBOUND', 'TRANSFER', 'ADJUSTMENT'] },
        indexes: ['productId', 'type', 'createdAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
      Receiving: {
        fields: { productId: 'string', binId: 'string', supplierName: 'string', quantity: 'Int', receivedBy: 'string', purchaseOrder: 'string?', receivedAt: 'DateTime @default(now())', notes: 'string?' },
        indexes: ['productId', 'receivedAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
      Shipping: {
        fields: { productId: 'string', binId: 'string', destination: 'string', quantity: 'Int', shippedBy: 'string', trackingNumber: 'string?', shippedAt: 'DateTime @default(now())', notes: 'string?' },
        indexes: ['productId', 'shippedAt'],
        relations: { belongsTo: ['Product', 'Bin'] }
      },
    },
    flows: ['Staff receives incoming goods and assigns bin locations', 'Products are stored in designated bin locations', 'Staff picks items from bins when orders come in', 'Items are packed for shipping', 'Manager reviews stock levels and generates reports'],
    endpoints: ['GET    /api/products                         ?category=&search=&page=&limit=', 'POST   /api/receiving                        { productId, binId, supplierName, quantity, purchaseOrder? }', 'POST   /api/stock-movements                  { productId, binId?, type, quantity, notes? }', 'GET    /api/stock-movements                  ?productId=&type=&dateFrom=&dateTo=', 'POST   /api/shipping                         { productId, binId, destination, quantity, trackingNumber? }', 'GET    /api/bins                             ?zone=&productId=', 'GET    /api/dashboard/warehouse-summary'],
    metrics: ['Inventory accuracy %', 'Bin utilization %', 'Order picking time', 'Receiving throughput', 'Stock turnover rate'],
    genericFeatures: ['Manajemen Produk', 'Bin & Lokasi', 'Stok Masuk/Keluar', 'Picking & Packing', 'Laporan Gudang'],
  },

  cold_chain: {
    name: 'Cold Chain / Rantai Dingin',
    actors: ['Operator', 'Manager', 'Admin'],
    entities: {
      Shipment: {
        fields: { trackingNumber: 'string @unique', productId: 'string', vehicleId: 'string', origin: 'string', destination: 'string', departureTime: 'DateTime', estimatedArrival: 'DateTime', status: 'ShipStatus @default(LOADING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ShipStatus: ['LOADING', 'IN_TRANSIT', 'DELIVERED', 'DELAYED', 'CANCELLED'] },
        indexes: ['trackingNumber', 'vehicleId', 'status'],
        relations: { belongsTo: ['Product', 'Vehicle'], hasMany: ['TemperatureLog'] }
      },
      Sensor: {
        fields: { code: 'string @unique', vehicleId: 'string?', location: 'string', type: 'string @default("TEMPERATURE")', unit: 'string @default("CELSIUS")', minThreshold: 'Float', maxThreshold: 'Float', isActive: 'Boolean @default(true)', lastReading: 'Float?', lastReadAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'vehicleId', 'isActive'],
        relations: { belongsTo: ['Vehicle'], hasMany: ['TemperatureLog'] }
      },
      TemperatureLog: {
        fields: { sensorId: 'string', shipmentId: 'string', temperature: 'Float', humidity: 'Float?', recordedAt: 'DateTime @default(now())' },
        indexes: ['sensorId', 'shipmentId', 'recordedAt'],
        relations: { belongsTo: ['Sensor', 'Shipment'] }
      },
      Product: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', minTemp: 'Float', maxTemp: 'Float', unit: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category'],
        relations: { hasMany: ['Shipment'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', type: 'string', capacity: 'Float', isActive: 'Boolean @default(true)', lastMaintenance: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Shipment', 'Sensor'] }
      },
    },
    flows: ['Operator loads temperature-sensitive products into vehicle', 'Sensors begin monitoring temperature during transit', 'System alerts if temperature exceeds thresholds', 'Shipment delivered — temperature logs verified', 'Manager reviews chain integrity report'],
    endpoints: ['POST   /api/shipments                        { productId, vehicleId, origin, destination, departureTime }', 'GET    /api/shipments                        ?status=&vehicleId=&dateFrom=&page=&limit=', 'PATCH  /api/shipments/:id/status              { status }', 'POST   /api/sensors                          { code, vehicleId?, type, minThreshold, maxThreshold }', 'POST   /api/temperature-logs                 { sensorId, shipmentId, temperature, humidity? }', 'GET    /api/temperature-logs/:shipmentId', 'GET    /api/dashboard/coldchain-summary'],
    metrics: ['Temperature breach rate', 'On-time delivery %', 'Sensor uptime', 'Average transit temperature', 'Product spoilage rate'],
    genericFeatures: ['Manajemen Pengiriman', 'Sensor Monitoring', 'Temperature Logs', 'Alert System', 'Cold Chain Report'],
  },

  freight: {
    name: 'Freight / Pengiriman Barang',
    actors: ['Shipper', 'Carrier', 'Admin'],
    entities: {
      Shipment: {
        fields: { trackingNumber: 'string @unique', shipperId: 'string', carrierId: 'string', origin: 'string', destination: 'string', weight: 'Float', volume: 'Float?', declaredValue: 'Float?', status: 'ShipStatus @default(QUOTED)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ShipStatus: ['QUOTED', 'BOOKED', 'PICKED_UP', 'IN_TRANSIT', 'DELIVERED', 'CANCELLED'] },
        indexes: ['trackingNumber', 'shipperId', 'carrierId', 'status'],
        relations: { belongsTo: ['Shipper', 'Carrier'], hasMany: ['Tracking', 'Payment'] }
      },
      Quote: {
        fields: { shipperId: 'string', origin: 'string', destination: 'string', weight: 'Float', volume: 'Float?', estimatedCost: 'Float', validUntil: 'DateTime', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['shipperId', 'status'],
        relations: { belongsTo: ['Shipper'] }
      },
      Tracking: {
        fields: { shipmentId: 'string', location: 'string', status: 'string', description: 'string?', timestamp: 'DateTime @default(now())' },
        indexes: ['shipmentId', 'timestamp'],
        relations: { belongsTo: ['Shipment'] }
      },
      Payment: {
        fields: { shipmentId: 'string', shipperId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['shipmentId', 'status'],
        relations: { belongsTo: ['Shipment', 'Shipper'] }
      },
      Document: {
        fields: { shipmentId: 'string', type: 'string', fileUrl: 'string', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Shipment'] }
      },
    },
    flows: ['Shipper requests a freight quote with weight and destination', 'Carrier provides pricing — shipper books shipment', 'Carrier picks up cargo from shipper', 'Cargo is in transit — tracking events recorded', 'Cargo delivered — payment processed and documents finalized'],
    endpoints: ['POST   /api/quotes                           { shipperId, origin, destination, weight, volume? }', 'GET    /api/quotes                           ?shipperId=&status=', 'POST   /api/shipments                        { shipperId, carrierId, origin, destination, weight, volume? }', 'GET    /api/shipments                        ?status=&carrierId=&page=&limit=', 'PATCH  /api/shipments/:id/status              { status }', 'POST   /api/tracking                         { shipmentId, location, status, description? }', 'POST   /api/payments                         { shipmentId, shipperId, amount, method }', 'GET    /api/dashboard/freight-summary'],
    metrics: ['Shipments per month', 'On-time delivery rate', 'Average transit time', 'Revenue per shipment', 'Customer satisfaction'],
    genericFeatures: ['Manajemen Pengiriman', 'Quote & Booking', 'Tracking Real-time', 'Pembayaran', 'Laporan Freight'],
  },

  homestay: {
    name: 'Homestay / Penginapan Rumah',
    actors: ['Host', 'Guest', 'Admin'],
    entities: {
      Property: {
        fields: { hostId: 'string', name: 'string', description: 'string?', address: 'string', city: 'string', maxGuests: 'Int', pricePerNight: 'Float', amenities: 'string (JSON)?', status: 'PropStatus @default(ACTIVE)', createdAt: 'DateTime @default(now())' },
        enums: { PropStatus: ['ACTIVE', 'INACTIVE', 'MAINTENANCE'] },
        indexes: ['hostId', 'city', 'status'],
        relations: { belongsTo: ['Host'], hasMany: ['Room', 'Booking', 'Review'] }
      },
      Room: {
        fields: { propertyId: 'string', name: 'string', capacity: 'Int', pricePerNight: 'Float', isAvailable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'isAvailable'],
        relations: { belongsTo: ['Property'] }
      },
      Booking: {
        fields: { propertyId: 'string', roomId: 'string?', guestId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'BookStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { BookStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['propertyId', 'guestId', 'checkIn', 'status'],
        relations: { belongsTo: ['Property', 'Guest', 'Room'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Booking', 'Review'] }
      },
      Payment: {
        fields: { bookingId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['bookingId', 'status'],
        relations: { belongsTo: ['Booking', 'Guest'] }
      },
      Review: {
        fields: { propertyId: 'string', guestId: 'string', bookingId: 'string', rating: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'guestId'],
        relations: { belongsTo: ['Property', 'Guest'] }
      },
    },
    flows: ['Host lists property with photos and pricing', 'Guest searches and books a property for specific dates', 'Guest checks in — host welcomes and provides keys', 'Guest stays and enjoys amenities', 'Guest checks out — host inspects property', 'Payment released to host — guest leaves review'],
    endpoints: ['GET    /api/properties                       ?city=&maxGuests=&minPrice=&maxPrice=&page=&limit=', 'POST   /api/properties                       { hostId, name, description?, address, city, maxGuests, pricePerNight }', 'POST   /api/bookings                         { propertyId, roomId?, guestId, checkIn, checkOut, guests }', 'GET    /api/bookings                         ?guestId=&status=&page=&limit=', 'PATCH  /api/bookings/:id/status               { status }', 'POST   /api/payments                         { bookingId, guestId, amount, method }', 'POST   /api/reviews                          { propertyId, guestId, bookingId, rating, comment? }', 'GET    /api/dashboard/homestay-summary'],
    metrics: ['Occupancy rate', 'Average stay duration', 'Revenue per property', 'Guest satisfaction', 'Booking conversion rate'],
    genericFeatures: ['Manajemen Properti', 'Booking System', 'Check-in/Check-out', 'Payment & Payout', 'Reviews & Rating'],
  },

  villa_rental: {
    name: 'Villa Rental / Sewa Villa',
    actors: ['Owner', 'Guest', 'Admin'],
    entities: {
      Villa: {
        fields: { ownerId: 'string', name: 'string', description: 'string?', location: 'string', city: 'string', maxGuests: 'Int', bedrooms: 'Int', bathrooms: 'Int', pricePerNight: 'Float', cleaningFee: 'Float @default(0)', amenities: 'string (JSON)?', status: 'VillaStatus @default(ACTIVE)', images: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        enums: { VillaStatus: ['ACTIVE', 'INACTIVE', 'BOOKED', 'MAINTENANCE'] },
        indexes: ['ownerId', 'city', 'status'],
        relations: { belongsTo: ['Owner'], hasMany: ['Booking', 'Amenity'] }
      },
      Booking: {
        fields: { villaId: 'string', guestId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'BookStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { BookStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['villaId', 'guestId', 'checkIn', 'status'],
        relations: { belongsTo: ['Villa', 'Guest'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', idPhoto: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Booking'] }
      },
      Payment: {
        fields: { bookingId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', depositAmount: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['bookingId', 'status'],
        relations: { belongsTo: ['Booking', 'Guest'] }
      },
      Amenity: {
        fields: { villaId: 'string', name: 'string', description: 'string?', isIncluded: 'Boolean @default(true)', price: 'Float?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Villa'] }
      },
    },
    flows: ['Guest searches for villas by location and dates', 'Guest books a villa — payment required for confirmation', 'Guest pays deposit — booking is confirmed', 'Guest checks in and enjoys the villa', 'Guest checks out — owner inspects property', 'Remaining payment processed — guest reviews'],
    endpoints: ['GET    /api/villas                           ?city=&maxGuests=&minPrice=&maxPrice=&page=&limit=', 'POST   /api/villas                           { ownerId, name, description?, location, city, maxGuests, bedrooms, bathrooms, pricePerNight }', 'POST   /api/bookings                         { villaId, guestId, checkIn, checkOut, guests }', 'GET    /api/bookings                         ?villaId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/bookings/:id/status               { status }', 'POST   /api/payments                         { bookingId, guestId, amount, method, depositAmount? }', 'GET    /api/dashboard/villa-summary'],
    metrics: ['Occupancy rate', 'Average booking value', 'Revenue per villa', 'Guest satisfaction', 'Booking lead time'],
    genericFeatures: ['Manajemen Villa', 'Booking System', 'Payment & Deposit', 'Check-in/Check-out', 'Reviews'],
  },

  guest_house: {
    name: 'Guest House / Losmen',
    actors: ['Receptionist', 'Guest', 'Admin'],
    entities: {
      Room: {
        fields: { roomNumber: 'string @unique', type: 'RoomType', pricePerNight: 'Float', capacity: 'Int', isAvailable: 'Boolean @default(true)', floor: 'Int?', amenities: 'string (JSON)?', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        enums: { RoomType: ['STANDARD', 'DELUXE', 'SUITE', 'FAMILY'] },
        indexes: ['roomNumber', 'type', 'isAvailable'],
        relations: { hasMany: ['Reservation'] }
      },
      Reservation: {
        fields: { guestId: 'string', roomId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', guests: 'Int', totalPrice: 'Float', status: 'ResStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ResStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['guestId', 'roomId', 'checkIn', 'status'],
        relations: { belongsTo: ['Guest', 'Room'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string?', phone: 'string', idNumber: 'string?', address: 'string?', isReturning: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Reservation'] }
      },
      Payment: {
        fields: { reservationId: 'string', guestId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['reservationId', 'status'],
        relations: { belongsTo: ['Reservation', 'Guest'] }
      },
      Service: {
        fields: { name: 'string', description: 'string?', price: 'Float', category: 'string', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Reservation'] }
      },
    },
    flows: ['Guest searches room availability and makes reservation', 'Receptionist confirms reservation and checks guest in', 'Guest stays and can request additional services', 'Guest checks out — receptionist processes payment', 'Payment settled and guest record updated'],
    endpoints: ['GET    /api/rooms                            ?type=&isAvailable=&capacity=&page=&limit=', 'POST   /api/reservations                     { guestId, roomId, checkIn, checkOut, guests }', 'GET    /api/reservations                     ?guestId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/reservations/:id/status           { status }', 'POST   /api/payments                         { reservationId, guestId, amount, method }', 'GET    /api/dashboard/guesthouse-summary'],
    metrics: ['Occupancy rate', 'Average stay length', 'Revenue per room', 'Guest return rate', 'Booking conversion'],
    genericFeatures: ['Manajemen Kamar', 'Reservasi', 'Check-in/Check-out', 'Pembayaran', 'Layanan Tambahan'],
  },

  resort: {
    name: 'Resort / Resort Wisata',
    actors: ['Receptionist', 'Guest', 'Staff', 'Manager'],
    entities: {
      Room: {
        fields: { roomNumber: 'string @unique', type: 'RoomType', pricePerNight: 'Float', capacity: 'Int', maxAdults: 'Int', maxChildren: 'Int', isAvailable: 'Boolean @default(true)', view: 'string?', amenities: 'string (JSON)?', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        enums: { RoomType: ['STANDARD', 'DELUXE', 'SUITE', 'VILLA', 'PENTHOUSE'] },
        indexes: ['roomNumber', 'type', 'isAvailable'],
        relations: { hasMany: ['Reservation'] }
      },
      Reservation: {
        fields: { guestId: 'string', roomId: 'string', checkIn: 'DateTime', checkOut: 'DateTime', adults: 'Int', children: 'Int', totalPrice: 'Float', status: 'ResStatus @default(PENDING)', specialRequests: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ResStatus: ['PENDING', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED'] },
        indexes: ['guestId', 'roomId', 'checkIn', 'status'],
        relations: { belongsTo: ['Guest', 'Room'], hasMany: ['Payment', 'Activity'] }
      },
      Guest: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', nationality: 'string?', idNumber: 'string?', idPhoto: 'string?', isVIP: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Reservation', 'Review'] }
      },
      Activity: {
        fields: { reservationId: 'string?', guestId: 'string', name: 'string', description: 'string?', date: 'DateTime', time: 'string', duration: 'Int', price: 'Float @default(0)', capacity: 'Int', bookedCount: 'Int @default(0)', status: 'string @default("AVAILABLE")' },
        indexes: ['reservationId', 'date'],
        relations: { belongsTo: ['Reservation'] }
      },
      Payment: {
        fields: { reservationId: 'string', guestId: 'string', amount: 'Float', method: 'string', type: 'string @default("ROOM")', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['reservationId', 'status'],
        relations: { belongsTo: ['Reservation', 'Guest'] }
      },
      Spa: {
        fields: { name: 'string', description: 'string?', duration: 'Int', price: 'Float', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Reservation'] }
      },
    },
    flows: ['Guest books a room for specific dates', 'Guest arrives — receptionist checks in and assigns room', 'Guest enjoys resort activities and spa', 'Staff provides housekeeping and room service', 'Guest checks out — all charges are settled', 'Guest provides feedback and review'],
    endpoints: ['GET    /api/rooms                            ?type=&isAvailable=&capacity=&page=&limit=', 'POST   /api/reservations                     { guestId, roomId, checkIn, checkOut, adults, children }', 'GET    /api/reservations                     ?status=&dateFrom=&page=&limit=', 'PATCH  /api/reservations/:id/status           { status }', 'POST   /api/activities                       { reservationId?, guestId, name, date, time, duration, price }', 'POST   /api/spa/bookings                     { reservationId?, guestId, spaId, date, time }', 'POST   /api/payments                         { reservationId, guestId, amount, method, type }', 'GET    /api/dashboard/resort-summary'],
    metrics: ['Occupancy rate', 'ADR (Average Daily Rate)', 'RevPAR', 'Guest satisfaction', 'Activity participation rate'],
    genericFeatures: ['Manajemen Kamar', 'Reservasi Tamu', 'Activities & Spa', 'Housekeeping', 'Billing & Payment'],
  },

  help_desk: {
    name: 'Help Desk / Layanan Pelanggan',
    actors: ['Agent', 'Customer', 'Admin'],
    entities: {
      Ticket: {
        fields: { ticketNumber: 'string @unique', customerId: 'string', agentId: 'string?', categoryId: 'string', subject: 'string', description: 'string', priority: 'PriorityType @default(MEDIUM)', status: 'TicketStatus @default(OPEN)', slaDeadline: 'DateTime?', resolvedAt: 'DateTime?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { PriorityType: ['LOW', 'MEDIUM', 'HIGH', 'URGENT'], TicketStatus: ['OPEN', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED', 'REOPENED'] },
        indexes: ['ticketNumber', 'customerId', 'agentId', 'status', 'priority'],
        relations: { belongsTo: ['Customer', 'Agent', 'Category'], hasMany: ['Response'] }
      },
      Customer: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', company: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Ticket'] }
      },
      Response: {
        fields: { ticketId: 'string', userId: 'string', message: 'string', attachments: 'string (JSON)?', isInternal: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['ticketId', 'createdAt'],
        relations: { belongsTo: ['Ticket'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', slaHours: 'Int @default(24)', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Ticket'] }
      },
      SLA: {
        fields: { ticketId: 'string', priority: 'string', deadline: 'DateTime', breached: 'Boolean @default(false)', breachedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['ticketId', 'breached'],
        relations: { belongsTo: ['Ticket'] }
      },
    },
    flows: ['Customer submits a support ticket with issue details', 'System assigns ticket to available agent based on category', 'Agent responds to customer and works on resolution', 'Agent marks ticket as resolved — customer confirms', 'Ticket is closed — satisfaction survey sent'],
    endpoints: ['GET    /api/tickets                          ?status=&priority=&agentId=&customerId=&page=&limit=', 'POST   /api/tickets                          { customerId, categoryId, subject, description, priority? }', 'PATCH  /api/tickets/:id/assign               { agentId }', 'PATCH  /api/tickets/:id/status                { status }', 'POST   /api/responses                        { ticketId, userId, message, isInternal? }', 'GET    /api/categories                       ?isActive=', 'GET    /api/dashboard/helpdesk-summary'],
    metrics: ['Tickets resolved per day', 'Average response time', 'SLA compliance %', 'Customer satisfaction score', 'First response time'],
    genericFeatures: ['Ticket Management', 'Auto-assignment', 'SLA Tracking', 'Knowledge Base', 'Customer Satisfaction'],
  },

  loyalty_program: {
    name: 'Loyalty Program / Program Loyalitas',
    actors: ['Member', 'Merchant', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', totalPoints: 'Int @default(0)', lifetimePoints: 'Int @default(0)', tierId: 'string?', joinDate: 'DateTime', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['email', 'tierId', 'status'],
        relations: { belongsTo: ['Tier'], hasMany: ['Points', 'Redemption'] }
      },
      Points: {
        fields: { memberId: 'string', merchantId: 'string?', amount: 'Int', type: 'string @default("EARNED")', source: 'string', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'type', 'expiresAt'],
        relations: { belongsTo: ['Member', 'Merchant'] }
      },
      Reward: {
        fields: { name: 'string', description: 'string?', pointsRequired: 'Int', merchantId: 'string?', category: 'string', stock: 'Int @default(0)', isActive: 'Boolean @default(true)', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['merchantId', 'category', 'isActive'],
        relations: { belongsTo: ['Merchant'], hasMany: ['Redemption'] }
      },
      Redemption: {
        fields: { memberId: 'string', rewardId: 'string', pointsSpent: 'Int', status: 'string @default("PENDING")', redeemedAt: 'DateTime @default(now())', fulfilledAt: 'DateTime?' },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member', 'Reward'] }
      },
      Tier: {
        fields: { name: 'string @unique', minPoints: 'Int @default(0)', multiplier: 'Float @default(1)', benefits: 'string (JSON)?', color: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Member'] }
      },
    },
    flows: ['Customer registers as loyalty member', 'Member earns points through purchases and activities', 'Member browses and redeems rewards with points', 'Member may advance to higher tier with more benefits', 'System checks for point expiration and sends reminders'],
    endpoints: ['POST   /api/members                          { name, email, phone? }', 'GET    /api/members                          ?tier=&status=&search=&page=&limit=', 'POST   /api/points                           { memberId, amount, source }', 'GET    /api/rewards                          ?category=&merchantId=&isActive=', 'POST   /api/redeem                           { memberId, rewardId }', 'GET    /api/tiers                            ?isActive=', 'GET    /api/dashboard/loyalty-summary'],
    metrics: ['Active members', 'Points earned per month', 'Redemption rate', 'Tier upgrade rate', 'Member retention %'],
    genericFeatures: ['Member Management', 'Points System', 'Rewards Catalog', 'Tier Management', 'Analytics'],
  },

  sales_pipeline: {
    name: 'Sales Pipeline / Pipeline Penjualan',
    actors: ['Sales', 'Manager', 'Admin'],
    entities: {
      Lead: {
        fields: { name: 'string', company: 'string?', email: 'string?', phone: 'string', source: 'string', score: 'Int @default(0)', status: 'LeadStatus @default(NEW)', assignedTo: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { LeadStatus: ['NEW', 'CONTACTED', 'QUALIFIED', 'DISQUALIFIED', 'CONVERTED'] },
        indexes: ['status', 'assignedTo', 'score'],
        relations: { belongsTo: ['Sales'], hasMany: ['Activity'] }
      },
      Deal: {
        fields: { leadId: 'string?', contactId: 'string?', name: 'string', value: 'Float', stage: 'DealStage', probability: 'Int @default(10)', expectedCloseDate: 'DateTime?', status: 'string @default("OPEN")', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { DealStage: ['PROSPECTING', 'QUALIFICATION', 'PROPOSAL', 'NEGOTIATION', 'CLOSED_WON', 'CLOSED_LOST'] },
        indexes: ['stage', 'salesId', 'value'],
        relations: { belongsTo: ['Sales'], hasMany: ['Activity'] }
      },
      Activity: {
        fields: { leadId: 'string?', dealId: 'string?', type: 'ActivityType', subject: 'string', description: 'string?', dueDate: 'DateTime?', completed: 'Boolean @default(false)', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { ActivityType: ['CALL', 'EMAIL', 'MEETING', 'DEMO', 'TASK'] },
        indexes: ['leadId', 'dealId', 'type', 'dueDate'],
        relations: { belongsTo: ['Lead', 'Deal'] }
      },
      Pipeline: {
        fields: { name: 'string @unique', stages: 'string (JSON)?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Deal'] }
      },
      Forecast: {
        fields: { period: 'string', totalValue: 'Float', weightedValue: 'Float', dealsCount: 'Int', confidence: 'Float @default(0)', generatedAt: 'DateTime @default(now())' },
        indexes: ['period']
      },
    },
    flows: ['Sales generates leads from multiple sources', 'Sales qualifies leads through discovery calls', 'Sales creates proposals and sends to prospects', 'Sales negotiates terms and handles objections', 'Deal is won — contract signed and handoff to delivery'],
    endpoints: ['GET    /api/leads                           ?status=&source=&assignedTo=&search=&page=&limit=', 'POST   /api/leads                           { name, company?, email?, phone, source, notes? }', 'PATCH  /api/leads/:id/status                 { status }', 'GET    /api/deals                            ?stage=&salesId=&page=&limit=', 'POST   /api/deals                            { leadId?, name, value, stage, probability, expectedCloseDate? }', 'PATCH  /api/deals/:id/stage                  { stage }', 'POST   /api/activities                       { leadId?, dealId?, type, subject, description?, dueDate? }', 'GET    /api/forecast                         ?period='],
    metrics: ['Lead conversion rate', 'Pipeline value (Rp)', 'Average deal size', 'Win rate %', 'Sales cycle length'],
    genericFeatures: ['Lead Management', 'Sales Pipeline', 'Aktivitas Follow-up', 'Forecasting', 'Dashboard Sales'],
  },

  project_management: {
    name: 'Project Management / Manajemen Proyek',
    actors: ['Manager', 'Member', 'Admin'],
    entities: {
      Project: {
        fields: { name: 'string', description: 'string?', startDate: 'DateTime', endDate: 'DateTime?', status: 'ProjStatus @default(PLANNING)', priority: 'string @default("MEDIUM")', budget: 'Float?', managerId: 'string', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { ProjStatus: ['PLANNING', 'IN_PROGRESS', 'ON_HOLD', 'COMPLETED', 'CANCELLED'] },
        indexes: ['managerId', 'status', 'priority'],
        relations: { belongsTo: ['Manager'], hasMany: ['Task', 'Milestone', 'Timesheet', 'Document'] }
      },
      Task: {
        fields: { projectId: 'string', title: 'string', description: 'string?', assigneeId: 'string?', priority: 'string @default("MEDIUM")', status: 'TaskStatus @default(TODO)', dueDate: 'DateTime?', estimatedHours: 'Float?', actualHours: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        enums: { TaskStatus: ['TODO', 'IN_PROGRESS', 'IN_REVIEW', 'DONE', 'CANCELLED'] },
        indexes: ['projectId', 'assigneeId', 'status'],
        relations: { belongsTo: ['Project', 'Member'] }
      },
      Milestone: {
        fields: { projectId: 'string', name: 'string', description: 'string?', dueDate: 'DateTime', status: 'string @default("PENDING")', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'status'],
        relations: { belongsTo: ['Project'] }
      },
      Timesheet: {
        fields: { projectId: 'string', memberId: 'string', date: 'DateTime', hours: 'Float', description: 'string?', billable: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'memberId', 'date'],
        relations: { belongsTo: ['Project', 'Member'] }
      },
      Document: {
        fields: { projectId: 'string', title: 'string', fileUrl: 'string', fileType: 'string', uploadedBy: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId'],
        relations: { belongsTo: ['Project'] }
      },
    },
    flows: ['Manager creates project with timeline and team', 'Manager assigns tasks to team members', 'Members update task progress and log hours', 'Manager reviews timesheets and task completion', 'Project completed — deliverables archived and report generated'],
    endpoints: ['GET    /api/projects                         ?status=&managerId=&page=&limit=', 'POST   /api/projects                         { name, description?, startDate, endDate?, budget?, managerId }', 'GET    /api/tasks                            ?projectId=&assigneeId=&status=&page=&limit=', 'POST   /api/tasks                            { projectId, title, description?, assigneeId?, dueDate? }', 'PATCH  /api/tasks/:id/status                  { status }', 'POST   /api/timesheets                       { projectId, memberId, date, hours, description? }', 'POST   /api/milestones                       { projectId, name, dueDate }', 'GET    /api/dashboard/project-summary'],
    metrics: ['Project completion rate', 'Task completion %', 'Budget adherence', 'Team utilization', 'On-time delivery rate'],
    genericFeatures: ['Manajemen Proyek', 'Task Board', 'Timesheet', 'Milestone Tracking', 'Laporan Proyek'],
  },

  task_management: {
    name: 'Task Management / Manajemen Tugas',
    actors: ['User', 'Admin'],
    entities: {
      Task: {
        fields: { userId: 'string', listId: 'string?', title: 'string', description: 'string?', priority: 'string @default("MEDIUM")', status: 'TaskStatus @default(TODO)', dueDate: 'DateTime?', estimatedMinutes: 'Int?', isRecurring: 'Boolean @default(false)', recurrenceRule: 'string?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { TaskStatus: ['TODO', 'IN_PROGRESS', 'DONE', 'ARCHIVED'] },
        indexes: ['userId', 'listId', 'status', 'priority', 'dueDate'],
        relations: { belongsTo: ['User', 'List'], hasMany: ['Label', 'Comment', 'Attachment'] }
      },
      List: {
        fields: { userId: 'string', name: 'string', color: 'string?', icon: 'string?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        indexes: ['userId'],
        relations: { belongsTo: ['User'], hasMany: ['Task'] }
      },
      Label: {
        fields: { name: 'string', color: 'string', userId: 'string' },
        indexes: ['userId'],
        relations: { belongsTo: ['User'] }
      },
      Comment: {
        fields: { taskId: 'string', userId: 'string', content: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['taskId'],
        relations: { belongsTo: ['Task', 'User'] }
      },
      Attachment: {
        fields: { taskId: 'string', fileName: 'string', fileUrl: 'string', fileSize: 'Int?', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Task'] }
      },
    },
    flows: ['User creates a task with title and due date', 'User organizes tasks into lists and adds labels', 'User works on tasks and marks progress', 'User reviews completed tasks and archives', 'Old completed tasks are archived automatically'],
    endpoints: ['GET    /api/lists                            ?userId=', 'POST   /api/lists                            { userId, name, color?, icon? }', 'GET    /api/tasks                            ?listId=&status=&priority=&dueDate=&page=&limit=', 'POST   /api/tasks                            { userId, listId?, title, description?, priority?, dueDate? }', 'PATCH  /api/tasks/:id/status                  { status }', 'POST   /api/comments                         { taskId, userId, content }', 'GET    /api/dashboard/task-summary'],
    metrics: ['Tasks completed per day', ['Tasks completed per day', 'Task completion rate'], 'Average completion time', 'Tasks by priority', 'Overdue task rate'],
    genericFeatures: ['Task Management', 'Lists & Labels', 'Priorities & Due Dates', 'Comments', 'Productivity Analytics'],
  },

  note_taking: {
    name: 'Note Taking / Catatan',
    actors: ['User'],
    entities: {
      Notebook: {
        fields: { name: 'string @unique', description: 'string?', color: 'string?', icon: 'string?', isDefault: 'Boolean @default(false)', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        relations: { hasMany: ['Note'] }
      },
      Note: {
        fields: { notebookId: 'string', title: 'string', content: 'string (HTML)?', isPinned: 'Boolean @default(false)', isArchived: 'Boolean @default(false)', tags: 'string (JSON)?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        indexes: ['notebookId', 'isPinned', 'isArchived', 'updatedAt'],
        relations: { belongsTo: ['Notebook'], hasMany: ['Tag', 'Attachment'] }
      },
      Tag: {
        fields: { name: 'string @unique', color: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Note'] }
      },
      Attachment: {
        fields: { noteId: 'string', fileName: 'string', fileUrl: 'string', fileType: 'string', fileSize: 'Int?', uploadedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Note'] }
      },
    },
    flows: ['User creates a notebook for organizing notes', 'User writes a note with rich text content', 'User organizes notes with tags and pinning', 'User searches and filters notes by keywords', 'User shares notes with others or archives old notes'],
    endpoints: ['GET    /api/notebooks                        ?isDefault=', 'POST   /api/notebooks                        { name, description?, color?, icon? }', 'GET    /api/notes                            ?notebookId=&tag=&search=&page=&limit=', 'POST   /api/notes                            { notebookId, title, content?, isPinned? }', 'PATCH  /api/notes/:id                         { title?, content?, isPinned?, isArchived? }', 'GET    /api/notes/search                     ?q='],
    metrics: ['Notes created per day', 'Active notebooks', 'Average note length', 'Search usage frequency', 'Tags per note'],
    genericFeatures: ['Notebook Organization', 'Rich Text Notes', 'Tags & Pinning', 'Search & Filter', 'Sharing & Export'],
  },

  okr_tracking: {
    name: 'OKR Tracking / Manajemen OKR',
    actors: ['User', 'Manager', 'Admin'],
    entities: {
      Objective: {
        fields: { title: 'string', description: 'string?', ownerId: 'string', period: 'string', status: 'ObjStatus @default(DRAFT)', progress: 'Int @default(0)', weight: 'Int @default(1)', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { ObjStatus: ['DRAFT', 'ACTIVE', 'ACHIEVED', 'CANCELLED'] },
        indexes: ['ownerId', 'period', 'status'],
        relations: { belongsTo: ['User'], hasMany: ['KeyResult'] }
      },
      KeyResult: {
        fields: { objectiveId: 'string', title: 'string', description: 'string?', type: 'string @default("PERCENTAGE")', startValue: 'Float @default(0)', currentValue: 'Float @default(0)', targetValue: 'Float', unit: 'string?', status: 'string @default("NOT_STARTED")', ownerId: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['objectiveId', 'ownerId', 'status'],
        relations: { belongsTo: ['Objective', 'User'] }
      },
      Initiative: {
        fields: { keyResultId: 'string', title: 'string', description: 'string?', ownerId: 'string', status: 'string @default("TODO")', dueDate: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['keyResultId', 'ownerId', 'status'],
        relations: { belongsTo: ['KeyResult', 'User'] }
      },
      CheckIn: {
        fields: { keyResultId: 'string', userId: 'string', previousValue: 'Float', currentValue: 'Float', confidence: 'Int?', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['keyResultId', 'createdAt'],
        relations: { belongsTo: ['KeyResult', 'User'] }
      },
      Score: {
        fields: { objectiveId: 'string', period: 'string', overallProgress: 'Float @default(0)', keyResultsCount: 'Int', achievedCount: 'Int', calculatedAt: 'DateTime @default(now())' },
        indexes: ['objectiveId', 'period'],
        relations: { belongsTo: ['Objective'] }
      },
    },
    flows: ['Manager sets quarterly objectives and key results', 'Teams align their OKRs with company objectives', 'Users track progress with weekly check-ins', 'Manager reviews progress during mid-quarter', 'Scores calculated at end of quarter — results documented'],
    endpoints: ['GET    /api/objectives                       ?period=&ownerId=&status=&page=&limit=', 'POST   /api/objectives                       { title, description?, ownerId, period }', 'POST   /api/key-results                     { objectiveId, title, type, targetValue, startValue?, ownerId }', 'PATCH  /api/key-results/:id/progress          { currentValue }', 'POST   /api/check-ins                        { keyResultId, userId, previousValue, currentValue, confidence?, comment? }', 'GET    /api/dashboard/okr-summary             ?period='],
    metrics: ['OKR completion rate', 'Key result progress', 'Check-in frequency', 'Confidence trend', 'Period-over-period growth'],
    genericFeatures: ['Objective Management', 'Key Results Tracking', 'Check-ins', 'Progress Dashboard', 'Quarterly Review'],
  },

  content_subscription: {
    name: 'Content Subscription / Langganan Konten',
    actors: ['Creator', 'Subscriber', 'Admin'],
    entities: {
      Content: {
        fields: { creatorId: 'string', title: 'string', description: 'string?', type: 'string @default("POST")', body: 'string (HTML)?', mediaUrl: 'string?', planId: 'string?', isExclusive: 'Boolean @default(false)', status: 'string @default("DRAFT")', publishedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'planId', 'status', 'publishedAt'],
        relations: { belongsTo: ['Creator', 'Plan'] }
      },
      Plan: {
        fields: { creatorId: 'string', name: 'string', description: 'string?', price: 'Float', billingPeriod: 'string @default("MONTHLY")', features: 'string (JSON)?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'isActive'],
        relations: { belongsTo: ['Creator'], hasMany: ['Content', 'Subscription'] }
      },
      Subscription: {
        fields: { subscriberId: 'string', creatorId: 'string', planId: 'string', startDate: 'DateTime', endDate: 'DateTime', status: 'SubStatus @default(ACTIVE)', autoRenew: 'Boolean @default(true)', cancelledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { SubStatus: ['ACTIVE', 'CANCELLED', 'EXPIRED', 'PAUSED'] },
        indexes: ['subscriberId', 'creatorId', 'planId', 'status'],
        relations: { belongsTo: ['Subscriber', 'Creator', 'Plan'] }
      },
      Payment: {
        fields: { subscriptionId: 'string', subscriberId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['subscriptionId', 'status'],
        relations: { belongsTo: ['Subscription', 'Subscriber'] }
      },
      Analytics: {
        fields: { creatorId: 'string', period: 'string', subscribers: 'Int', revenue: 'Float', views: 'Int', engagement: 'Float?', calculatedAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'period']
      },
    },
    flows: ['Creator publishes exclusive content for subscribers', 'Subscriber signs up for a paid subscription plan', 'Subscriber gains access to exclusive content', 'Creator gets paid — subscription revenue analytics', 'Creator analyzes subscriber growth and revenue trends'],
    endpoints: ['GET    /api/plans                            ?creatorId=&isActive=', 'POST   /api/plans                            { creatorId, name, description?, price, billingPeriod }', 'GET    /api/content                          ?creatorId=&planId=&status=&page=&limit=', 'POST   /api/subscriptions                    { subscriberId, creatorId, planId }', 'GET    /api/subscriptions                    ?subscriberId=&status=', 'PATCH  /api/subscriptions/:id/status          { status }', 'POST   /api/payments                         { subscriptionId, subscriberId, amount, method }', 'GET    /api/dashboard/subscription-summary'],
    metrics: ['Subscriber count', 'Monthly recurring revenue', 'Churn rate', 'Content engagement', 'Revenue per subscriber'],
    genericFeatures: ['Content Management', 'Subscription Plans', 'Member Access', 'Payment Processing', 'Creator Analytics'],
  },

  podcast_platform: {
    name: 'Podcast Platform / Platform Podcast',
    actors: ['Host', 'Listener', 'Admin'],
    entities: {
      Podcast: {
        fields: { hostId: 'string', title: 'string', description: 'string?', coverArt: 'string?', category: 'string', language: 'string @default("id")', isExplicit: 'Boolean @default(false)', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        indexes: ['hostId', 'category', 'status'],
        relations: { belongsTo: ['Host'], hasMany: ['Episode', 'Subscription'] }
      },
      Episode: {
        fields: { podcastId: 'string', title: 'string', description: 'string?', audioUrl: 'string', duration: 'Int', episodeNumber: 'Int', season: 'Int @default(1)', status: 'string @default("DRAFT")', publishedAt: 'DateTime?', listenCount: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'episodeNumber', 'status', 'publishedAt'],
        relations: { belongsTo: ['Podcast'] }
      },
      Subscription: {
        fields: { listenerId: 'string', podcastId: 'string', subscribedAt: 'DateTime @default(now())' },
        indexes: ['listenerId', 'podcastId'],
        relations: { belongsTo: ['Listener', 'Podcast'] }
      },
      Analytics: {
        fields: { podcastId: 'string', episodeId: 'string?', period: 'string', listens: 'Int', uniqueListeners: 'Int', avgListenDuration: 'Float?', completionRate: 'Float?', calculatedAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'episodeId', 'period']
      },
      Payment: {
        fields: { podcastId: 'string', hostId: 'string', amount: 'Float', type: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['podcastId', 'status'],
        relations: { belongsTo: ['Podcast', 'Host'] }
      },
    },
    flows: ['Host records and uploads a new episode', 'Episode is published to subscribers', 'Listeners subscribe and stream episodes', 'Host monetizes through ads or listener support', 'Host reviews analytics on listener engagement'],
    endpoints: ['GET    /api/podcasts                         ?category=&language=&status=&page=&limit=', 'POST   /api/podcasts                         { hostId, title, description?, category, coverArt? }', 'POST   /api/episodes                         { podcastId, title, audioUrl, duration, description? }', 'GET    /api/episodes/:podcastId               ?status=&page=&limit=', 'POST   /api/subscriptions                    { listenerId, podcastId }', 'GET    /api/analytics/:podcastId              ?period=', 'GET    /api/dashboard/podcast-summary'],
    metrics: ['Total subscribers', 'Episode downloads', 'Avg listen duration', 'Completion rate', 'Monetization revenue'],
    genericFeatures: ['Podcast Management', 'Episode Publishing', 'Subscriber Base', 'Monetization', 'Analytics Dashboard'],
  },

  template_marketplace: {
    name: 'Template Marketplace / Marketplace Template',
    actors: ['Creator', 'Buyer', 'Admin'],
    entities: {
      Template: {
        fields: { creatorId: 'string', title: 'string', description: 'string?', categoryId: 'string', price: 'Float @default(0)', fileUrl: 'string', previewUrl: 'string?', format: 'string', tags: 'string (JSON)?', downloadCount: 'Int @default(0)', status: 'string @default("PENDING")', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'categoryId', 'status', 'price'],
        relations: { belongsTo: ['Creator', 'Category'], hasMany: ['Purchase', 'Review'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', icon: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Template'] }
      },
      Purchase: {
        fields: { buyerId: 'string', templateId: 'string', price: 'Float', status: 'string @default("PENDING")', purchasedAt: 'DateTime @default(now())' },
        indexes: ['buyerId', 'templateId'],
        relations: { belongsTo: ['Buyer', 'Template'] }
      },
      Review: {
        fields: { templateId: 'string', buyerId: 'string', rating: 'Int', comment: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['templateId', 'buyerId'],
        relations: { belongsTo: ['Template', 'Buyer'] }
      },
      Payout: {
        fields: { creatorId: 'string', amount: 'Float', period: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['creatorId', 'status'],
        relations: { belongsTo: ['Creator'] }
      },
    },
    flows: ['Creator uploads a template with preview and details', 'Template is reviewed and listed in marketplace', 'Buyer browses categories and purchases template', 'Buyer downloads template after payment', 'Creator receives payout based on sales'],
    endpoints: ['GET    /api/templates                        ?categoryId=&format=&minPrice=&maxPrice=&search=&page=&limit=', 'POST   /api/templates                        { creatorId, title, description?, categoryId, price, fileUrl, format }', 'GET    /api/categories                       ?isActive=', 'POST   /api/purchases                        { buyerId, templateId }', 'GET    /api/purchases/:buyerId', 'POST   /api/reviews                          { templateId, buyerId, rating, comment? }', 'GET    /api/dashboard/template-summary'],
    metrics: ['Templates sold', 'Revenue per creator', 'Average rating', 'Download count', 'Category distribution'],
    genericFeatures: ['Template Management', 'Category Browse', 'Purchase & Download', 'Creator Payouts', 'Rating & Reviews'],
  },

  fishery: {
    name: 'Fishery / Perikanan',
    actors: ['Farmer', 'Worker', 'Buyer', 'Admin'],
    entities: {
      Pond: {
        fields: { code: 'string @unique', name: 'string', area: 'Float', depth: 'Float?', waterType: 'string @default("FRESHWATER")', fishType: 'string', capacity: 'Int', status: 'string @default("ACTIVE")', location: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'status'],
        relations: { hasMany: ['Fish', 'Feed'] }
      },
      Fish: {
        fields: { pondId: 'string', batchNumber: 'string', species: 'string', quantity: 'Int', avgWeight: 'Float', stockingDate: 'DateTime', status: 'string @default("GROWING")', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'batchNumber', 'status'],
        relations: { belongsTo: ['Pond'], hasMany: ['Harvest'] }
      },
      Feed: {
        fields: { pondId: 'string', feedType: 'string', quantity: 'Float', unit: 'string @default("KG")', cost: 'Float', date: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'date'],
        relations: { belongsTo: ['Pond'] }
      },
      Harvest: {
        fields: { pondId: 'string', fishId: 'string', quantity: 'Int', totalWeight: 'Float', harvestDate: 'DateTime', status: 'string @default("COMPLETED")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['pondId', 'harvestDate'],
        relations: { belongsTo: ['Pond', 'Fish'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Int', weight: 'Float', pricePerKg: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'buyerId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
      Inventory: {
        fields: { productName: 'string', quantity: 'Float', unit: 'string', minStock: 'Float @default(0)', updatedAt: 'DateTime @default(now())' }
      },
    },
    flows: ['Farmer stocks ponds with fish fry', 'Worker provides feed according to schedule', 'Farmer monitors fish growth and pond conditions', 'Fish are harvested when reaching target weight', 'Harvested fish sold to buyers at market price'],
    endpoints: ['GET    /api/ponds                            ?status=&fishType=', 'POST   /api/ponds                            { code, name, area, waterType, fishType, capacity }', 'POST   /api/fish                            { pondId, batchNumber, species, quantity, avgWeight }', 'POST   /api/feed                            { pondId, feedType, quantity, unit, cost }', 'POST   /api/harvest                         { pondId, fishId, quantity, totalWeight }', 'POST   /api/sales                           { harvestId, buyerId, quantity, weight, pricePerKg }', 'GET    /api/dashboard/fishery-summary'],
    metrics: ['Fish survival rate', 'Feed conversion ratio', 'Harvest weight per pond', 'Revenue per cycle', 'Average selling price'],
    genericFeatures: ['Manajemen Kolam', 'Pakan & Perawatan', 'Panen & Hasil', 'Penjualan Ikan', 'Laporan Perikanan'],
  },

  plantation: {
    name: 'Plantation / Perkebunan',
    actors: ['Farmer', 'Worker', 'Buyer', 'Admin'],
    entities: {
      Field: {
        fields: { code: 'string @unique', name: 'string', area: 'Float', location: 'string', soilType: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'status'],
        relations: { hasMany: ['Crop', 'Planting'] }
      },
      Crop: {
        fields: { name: 'string', variety: 'string?', growingPeriod: 'Int', expectedYield: 'Float', unit: 'string @default("KG")', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Planting', 'Harvest'] }
      },
      Planting: {
        fields: { fieldId: 'string', cropId: 'string', plantDate: 'DateTime', quantity: 'Int', spacing: 'string?', status: 'string @default("GROWING")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['fieldId', 'cropId', 'status'],
        relations: { belongsTo: ['Field', 'Crop'], hasMany: ['Harvest'] }
      },
      Harvest: {
        fields: { plantingId: 'string', fieldId: 'string', cropId: 'string', quantity: 'Float', unit: 'string', quality: 'string?', harvestDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['plantingId', 'harvestDate'],
        relations: { belongsTo: ['Planting', 'Field', 'Crop'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Float', pricePerUnit: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'buyerId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
      Inventory: {
        fields: { productName: 'string', quantity: 'Float', unit: 'string', minStock: 'Float @default(0)', updatedAt: 'DateTime @default(now())' }
      },
    },
    flows: ['Farmer prepares land and plants crops', 'Worker maintains crops — watering, fertilizing, pest control', 'Crops grow and are monitored for readiness', 'Harvest is collected and sorted by quality', 'Produce is processed and sold to buyers'],
    endpoints: ['GET    /api/fields                           ?status=&location=', 'POST   /api/fields                           { code, name, area, location, soilType? }', 'POST   /api/plantings                       { fieldId, cropId, plantDate, quantity }', 'POST   /api/harvests                        { plantingId, fieldId, cropId, quantity, unit, quality? }', 'GET    /api/harvests                         ?fieldId=&dateFrom=&dateTo=', 'POST   /api/sales                           { harvestId, buyerId, quantity, pricePerUnit }', 'GET    /api/dashboard/plantation-summary'],
    metrics: ['Yield per hectare', ['Yield per hectare', 'Crop survival rate'], 'Harvest cycle time', 'Revenue per field', 'Crop quality distribution'],
    genericFeatures: ['Manajemen Lahan', 'Tanam & Perawatan', 'Panen & Sortir', 'Penjualan Hasil', 'Laporan Perkebunan'],
  },

  greenhouse: {
    name: 'Greenhouse / Rumah Kaca',
    actors: ['Farmer', 'Tech', 'Admin'],
    entities: {
      Crop: {
        fields: { name: 'string', variety: 'string?', growingPeriod: 'Int', expectedYield: 'Float', unit: 'string @default("KG")', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Harvest'] }
      },
      Sensor: {
        fields: { code: 'string @unique', type: 'SensorType', unit: 'string', location: 'string', minThreshold: 'Float', maxThreshold: 'Float', isActive: 'Boolean @default(true)', lastReading: 'Float?', lastReadAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { SensorType: ['TEMPERATURE', 'HUMIDITY', 'SOIL_MOISTURE', 'LIGHT', 'CO2', 'PH'] },
        indexes: ['code', 'type', 'isActive'],
        relations: { hasMany: ['EnvironmentLog'] }
      },
      EnvironmentLog: {
        fields: { sensorId: 'string', reading: 'Float', recordedAt: 'DateTime @default(now())' },
        indexes: ['sensorId', 'recordedAt'],
        relations: { belongsTo: ['Sensor'] }
      },
      Harvest: {
        fields: { cropId: 'string', quantity: 'Float', unit: 'string', quality: 'string?', harvestDate: 'DateTime', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['cropId', 'harvestDate'],
        relations: { belongsTo: ['Crop'], hasMany: ['Sale'] }
      },
      Sale: {
        fields: { harvestId: 'string', buyerId: 'string', quantity: 'Float', pricePerUnit: 'Float', totalPrice: 'Float', saleDate: 'DateTime', createdAt: 'DateTime @default(now())' },
        indexes: ['harvestId', 'saleDate'],
        relations: { belongsTo: ['Harvest', 'Buyer'] }
      },
    },
    flows: ['Farmer plants crops in greenhouse beds', 'Sensors monitor temperature, humidity and soil moisture', 'System adjusts environment automatically or alerts tech', 'Crops are harvested at peak quality', 'Produce is sold fresh to buyers'],
    endpoints: ['GET    /api/sensors                          ?type=&isActive=', 'POST   /api/sensors                          { code, type, unit, location, minThreshold, maxThreshold }', 'GET    /api/environment-logs                 ?sensorId=&dateFrom=&dateTo=', 'POST   /api/harvests                         { cropId, quantity, unit, quality? }', 'POST   /api/sales                           { harvestId, buyerId, quantity, pricePerUnit }', 'GET    /api/dashboard/greenhouse-summary'],
    metrics: ['Yield per sq meter', ['Yield per sq meter', 'Environment stability %'], 'Energy efficiency', 'Crop cycle time', 'Sensor uptime'],
    genericFeatures: ['Crop Management', 'Sensor Monitoring', 'Environment Control', 'Harvest Tracking', 'Sales & Yield'],
  },

  car_wash: {
    name: 'Car Wash / Cuci Mobil',
    actors: ['Customer', 'Worker', 'Owner'],
    entities: {
      Service: {
        fields: { name: 'string @unique', description: 'string?', price: 'Float', duration: 'Int', category: 'string @default("EXTERIOR")', isActive: 'Boolean @default(true)' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Order'] }
      },
      Order: {
        fields: { customerId: 'string', vehicleId: 'string', serviceId: 'string', workerId: 'string?', status: 'OrderStatus @default(PENDING)', queueNumber: 'Int?', notes: 'string?', startedAt: 'DateTime?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'workerId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Service', 'Worker'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', color: 'string?', year: 'Int?', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['Order'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', isMember: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Order', 'Vehicle'] }
      },
      Payment: {
        fields: { orderId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Order'] }
      },
      Package: {
        fields: { name: 'string @unique', description: 'string?', services: 'string (JSON)?', price: 'Float', visits: 'Int @default(1)', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Order'] }
      },
    },
    flows: ['Customer arrives at car wash', 'Customer selects service package', 'Worker washes the car — interior and exterior', 'Car is dried and quality checked', 'Customer pays and leaves'],
    endpoints: ['GET    /api/services                         ?category=&isActive=', 'POST   /api/orders                           { customerId, vehicleId, serviceId, notes? }', 'GET    /api/orders                           ?status=&dateFrom=&page=&limit=', 'PATCH  /api/orders/:id/status                 { status }', 'POST   /api/payments                         { orderId, amount, method }', 'GET    /api/dashboard/carwash-summary'],
    metrics: ['Cars washed per day', 'Average service time', 'Revenue per day', 'Customer return rate', 'Package upsell rate'],
    genericFeatures: ['Manajemen Antrian', 'Layanan Cuci', 'Pembayaran', 'Member Management', 'Laporan Harian'],
  },

  motorcycle_workshop: {
    name: 'Motorcycle Workshop / Bengkel Motor',
    actors: ['Customer', 'Mechanic', 'Owner'],
    entities: {
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', year: 'Int?', mileage: 'Int?', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['ServiceOrder'] }
      },
      ServiceOrder: {
        fields: { customerId: 'string', vehicleId: 'string', mechanicId: 'string?', complaint: 'string', diagnosis: 'string?', estimateAmount: 'Float?', status: 'OrderStatus @default(PENDING)', startedAt: 'DateTime?', completedAt: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'DIAGNOSED', 'ESTIMATED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'mechanicId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Mechanic'], hasMany: ['SparePart'] }
      },
      SparePart: {
        fields: { name: 'string', serviceOrderId: 'string?', stock: 'Int @default(0)', price: 'Float', supplier: 'string?', isOriginal: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['serviceOrderId'],
        relations: { belongsTo: ['ServiceOrder'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Vehicle', 'ServiceOrder'] }
      },
      Payment: {
        fields: { serviceOrderId: 'string', totalAmount: 'Float', partsCost: 'Float @default(0)', serviceCost: 'Float @default(0)', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['ServiceOrder'] }
      },
    },
    flows: ['Customer brings motorcycle with a problem', 'Mechanic diagnoses the issue and provides estimate', 'Customer approves estimate — repair begins', 'Mechanic repairs and replaces parts as needed', 'Customer pays and picks up motorcycle'],
    endpoints: ['POST   /api/service-orders                   { customerId, vehicleId, complaint }', 'GET    /api/service-orders                   ?status=&customerId=&dateFrom=&page=&limit=', 'PATCH  /api/service-orders/:id/diagnose       { diagnosis, estimateAmount }', 'PATCH  /api/service-orders/:id/status         { status }', 'POST   /api/spare-parts                      { serviceOrderId, name, price, isOriginal? }', 'POST   /api/payments                         { serviceOrderId, totalAmount, partsCost, serviceCost, method }', 'GET    /api/dashboard/workshop-summary'],
    metrics: ['Orders per day', 'Average repair time', 'Parts vs labor ratio', 'Customer retention', 'Estimate accuracy'],
    genericFeatures: ['Manajemen Antrian', 'Diagnosa & Estimasi', 'Reparasi Motor', 'Spare Part', 'Pembayaran'],
  },

  tire_shop: {
    name: 'Tire Shop / Toko Ban',
    actors: ['Customer', 'Technician', 'Owner'],
    entities: {
      Product: {
        fields: { name: 'string', brand: 'string', size: 'string', type: 'string @default("RADIAL")', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(5)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['brand', 'size', 'type'],
        relations: { hasMany: ['ServiceOrder'] }
      },
      Vehicle: {
        fields: { plateNumber: 'string @unique', customerId: 'string', brand: 'string', model: 'string', year: 'Int?', tireSize: 'string', createdAt: 'DateTime @default(now())' },
        indexes: ['plateNumber', 'customerId'],
        relations: { belongsTo: ['Customer'], hasMany: ['ServiceOrder'] }
      },
      ServiceOrder: {
        fields: { customerId: 'string', vehicleId: 'string', technicianId: 'string?', serviceType: 'string @default("REPLACE")', status: 'OrderStatus @default(PENDING)', notes: 'string?', startedAt: 'DateTime?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'INSPECTED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'vehicleId', 'technicianId', 'status'],
        relations: { belongsTo: ['Customer', 'Vehicle', 'Technician'] }
      },
      Customer: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', totalVisits: 'Int @default(0)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Vehicle', 'ServiceOrder'] }
      },
      Payment: {
        fields: { serviceOrderId: 'string', totalAmount: 'Float', productCost: 'Float @default(0)', serviceCost: 'Float @default(0)', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['ServiceOrder'] }
      },
    },
    flows: ['Customer arrives for tire inspection', 'Technician inspects tires — checks tread depth and pressure', 'Technician replaces worn tires with new ones', 'Tires are balanced and aligned', 'Customer pays and drives away'],
    endpoints: ['GET    /api/products                         ?brand=&size=&type=&isActive=', 'POST   /api/products                         { name, brand, size, type, price, stock }', 'POST   /api/service-orders                   { customerId, vehicleId, serviceType? }', 'GET    /api/service-orders                   ?status=&customerId=&page=&limit=', 'PATCH  /api/service-orders/:id/status         { status }', 'POST   /api/payments                         { serviceOrderId, totalAmount, productCost, serviceCost, method }', 'GET    /api/dashboard/tireshop-summary'],
    metrics: ['Tires sold per day', 'Average service time', 'Revenue per customer', 'Stock turnover rate', ['Stock turnover rate', 'Tire brand popularity']],
    genericFeatures: ['Manajemen Produk', 'Service Order', 'Penggantian Ban', 'Spooring & Balancing', 'Pembayaran'],
  },

  rental_management: {
    name: 'Rental Management / Manajemen Sewa',
    actors: ['Owner', 'Tenant', 'Manager', 'Admin'],
    entities: {
      Property: {
        fields: { code: 'string @unique', name: 'string', address: 'string', type: 'string @default("APARTMENT")', city: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['code', 'city'],
        relations: { hasMany: ['Unit', 'Lease'] }
      },
      Unit: {
        fields: { propertyId: 'string', unitNumber: 'string @unique', floor: 'Int?', bedrooms: 'Int', bathrooms: 'Int', area: 'Float?', monthlyRent: 'Float', depositAmount: 'Float', isOccupied: 'Boolean @default(false)', status: 'string @default("AVAILABLE")', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'unitNumber', 'isOccupied', 'status'],
        relations: { belongsTo: ['Property'], hasMany: ['Lease', 'Maintenance'] }
      },
      Tenant: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', emergencyContact: 'string?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Lease', 'Payment'] }
      },
      Lease: {
        fields: { unitId: 'string', tenantId: 'string', startDate: 'DateTime', endDate: 'DateTime', monthlyRent: 'Float', depositAmount: 'Float @default(0)', status: 'LeaseStatus @default(ACTIVE)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { LeaseStatus: ['ACTIVE', 'EXPIRED', 'TERMINATED', 'RENEWED'] },
        indexes: ['unitId', 'tenantId', 'status'],
        relations: { belongsTo: ['Unit', 'Tenant'] }
      },
      Payment: {
        fields: { leaseId: 'string', tenantId: 'string', amount: 'Float', type: 'string @default("RENT")', period: 'string', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['leaseId', 'tenantId', 'period', 'status'],
        relations: { belongsTo: ['Lease', 'Tenant'] }
      },
      Maintenance: {
        fields: { unitId: 'string', tenantId: 'string', issue: 'string', priority: 'string @default("MEDIUM")', status: 'string @default("REPORTED")', assignedTo: 'string?', scheduledAt: 'DateTime?', completedAt: 'DateTime?', cost: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'tenantId', 'status', 'priority'],
        relations: { belongsTo: ['Unit', 'Tenant'] }
      },
    },
    flows: ['Owner lists property and units for rent', 'Tenant signs a lease agreement for a unit', 'Owner collects monthly rent payments', 'Tenant submits maintenance requests as needed', 'Lease is renewed or terminated at end of term'],
    endpoints: ['GET    /api/properties                       ?city=&isActive=', 'POST   /api/properties                       { code, name, address, type, city }', 'GET    /api/units                            ?propertyId=&status=&minPrice=&maxPrice=', 'POST   /api/leases                           { unitId, tenantId, startDate, endDate, monthlyRent }', 'GET    /api/payments                         ?leaseId=&status=&period=&page=&limit=', 'POST   /api/maintenance                      { unitId, tenantId, issue, priority }', 'PATCH  /api/maintenance/:id/status            { status }', 'GET    /api/dashboard/rental-summary'],
    metrics: ['Occupancy rate', ['Occupancy rate', 'Rent collection rate'], 'Average rent per unit', 'Maintenance response time', 'Tenant retention rate'],
    genericFeatures: ['Manajemen Properti', 'Unit & Sewa', 'Pembayaran Sewa', 'Maintenance', 'Laporan Penyewaan'],
  },

  real_estate_agency: {
    name: 'Real Estate Agency / Agen Properti',
    actors: ['Agent', 'Client', 'Buyer', 'Admin'],
    entities: {
      Property: {
        fields: { listingId: 'string', agentId: 'string', title: 'string', description: 'string?', address: 'string', city: 'string', price: 'Float', type: 'string @default("HOUSE")', bedrooms: 'Int?', bathrooms: 'Int?', landArea: 'Float?', buildingArea: 'Float?', images: 'string (JSON)?', status: 'string @default("FOR_SALE")', createdAt: 'DateTime @default(now())' },
        indexes: ['listingId', 'agentId', 'city', 'price', 'status'],
        relations: { belongsTo: ['Agent'], hasMany: ['Showing', 'Offer'] }
      },
      Listing: {
        fields: { propertyId: 'string', agentId: 'string', price: 'Float', commission: 'Float?', status: 'string @default("ACTIVE")', expiresAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'agentId', 'status'],
        relations: { belongsTo: ['Property', 'Agent'] }
      },
      Client: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', type: 'string @default("BUYER")', budget: 'Float?', preferences: 'string (JSON)?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Showing', 'Offer'] }
      },
      Showing: {
        fields: { propertyId: 'string', agentId: 'string', clientId: 'string', scheduledAt: 'DateTime', status: 'string @default("SCHEDULED")', feedback: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['propertyId', 'agentId', 'clientId', 'scheduledAt'],
        relations: { belongsTo: ['Property', 'Agent', 'Client'] }
      },
      Offer: {
        fields: { propertyId: 'string', clientId: 'string', agentId: 'string', offeredPrice: 'Float', status: 'OfferStatus @default(SUBMITTED)', notes: 'string?', respondedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        enums: { OfferStatus: ['SUBMITTED', 'NEGOTIATING', 'ACCEPTED', 'REJECTED', 'WITHDRAWN'] },
        indexes: ['propertyId', 'clientId', 'status'],
        relations: { belongsTo: ['Property', 'Client', 'Agent'] }
      },
      Commission: {
        fields: { listingId: 'string', agentId: 'string', amount: 'Float', percentage: 'Float', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Listing', 'Agent'] }
      },
    },
    flows: ['Agent lists a property with photos and details', 'Client schedules a property showing', 'Agent shows the property to interested buyers', 'Buyer submits an offer — agent negotiates', 'Deal closes — agent receives commission'],
    endpoints: ['GET    /api/properties                       ?city=&type=&minPrice=&maxPrice=&status=&page=&limit=', 'POST   /api/properties                       { agentId, title, description?, address, city, price, type }', 'POST   /api/showings                        { propertyId, agentId, clientId, scheduledAt }', 'POST   /api/offers                           { propertyId, clientId, agentId, offeredPrice }', 'PATCH  /api/offers/:id/status                { status }', 'GET    /api/commissions                      ?agentId=&status=', 'GET    /api/dashboard/realestate-summary'],
    metrics: ['Listings per agent', 'Showing conversion rate', 'Average days on market', 'Commission per deal', 'Offer-to-close ratio'],
    genericFeatures: ['Property Listings', 'Showing Management', 'Offer & Negotiation', 'Commission Tracking', 'Client Management'],
  },

  strata_management: {
    name: 'Strata Management / Manajemen Apartemen',
    actors: ['Manager', 'Owner', 'Committee', 'Admin'],
    entities: {
      Unit: {
        fields: { unitNumber: 'string @unique', floor: 'Int', type: 'string', area: 'Float?', ownerId: 'string', monthlyFee: 'Float', parkingSlots: 'Int @default(1)', isRented: 'Boolean @default(false)', status: 'string @default("OCCUPIED")', createdAt: 'DateTime @default(now())' },
        indexes: ['unitNumber', 'ownerId', 'status'],
        relations: { belongsTo: ['Owner'], hasMany: ['Fee', 'Maintenance'] }
      },
      Owner: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', idNumber: 'string?', address: 'string?', isCommittee: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Unit'] }
      },
      Fee: {
        fields: { unitId: 'string', period: 'string', amount: 'Float', dueDate: 'DateTime', paidAt: 'DateTime?', status: 'string @default("PENDING")', lateFee: 'Float @default(0)', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'period', 'status'],
        relations: { belongsTo: ['Unit'] }
      },
      Maintenance: {
        fields: { unitId: 'string', reportedBy: 'string', issue: 'string', area: 'string @default("UNIT")', priority: 'string @default("MEDIUM")', status: 'string @default("REPORTED")', estimatedCost: 'Float?', actualCost: 'Float?', vendor: 'string?', completedAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['unitId', 'status', 'priority'],
        relations: { belongsTo: ['Unit'] }
      },
      Meeting: {
        fields: { title: 'string', date: 'DateTime', agenda: 'string?', minutes: 'string?', attendees: 'string (JSON)?', status: 'string @default("SCHEDULED")', createdAt: 'DateTime @default(now())' },
        indexes: ['date', 'status']
      },
    },
    flows: ['Manager collects monthly maintenance fees from owners', 'Manager schedules maintenance for common areas', 'Committee holds meetings to discuss building matters', 'Manager generates financial reports', 'Budget is planned and approved for next period'],
    endpoints: ['GET    /api/units                            ?status=&floor=', 'POST   /api/units                            { unitNumber, floor, type, ownerId, monthlyFee }', 'GET    /api/fees                             ?unitId=&period=&status=&page=&limit=', 'POST   /api/maintenance                      { unitId, issue, priority, area? }', 'POST   /api/meetings                         { title, date, agenda? }', 'GET    /api/dashboard/strata-summary'],
    metrics: ['Fee collection rate', ['Fee collection rate', 'Maintenance turnaround'], 'Meeting attendance', 'Budget variance', 'Owner satisfaction'],
    genericFeatures: ['Manajemen Unit', ['Manajemen Unit', 'Iuran Bulanan'], 'Maintenance & Perbaikan', 'Rapat & Notulen', 'Laporan Keuangan'],
  },

  sports_club: {
    name: 'Sports Club / Klub Olahraga',
    actors: ['Member', 'Coach', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', dateOfBirth: 'DateTime?', emergencyContact: 'string?', medicalNotes: 'string?', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Membership', 'Session', 'Attendance'] }
      },
      Membership: {
        fields: { memberId: 'string', type: 'MembType', startDate: 'DateTime', endDate: 'DateTime', price: 'Float', status: 'string @default("ACTIVE")', autoRenew: 'Boolean @default(false)', createdAt: 'DateTime @default(now())' },
        enums: { MembType: ['MONTHLY', 'QUARTERLY', 'YEARLY', 'TRIAL'] },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'] }
      },
      Session: {
        fields: { coachId: 'string', sport: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', location: 'string', capacity: 'Int', participants: 'Int @default(0)', status: 'string @default("SCHEDULED")', createdAt: 'DateTime @default(now())' },
        indexes: ['coachId', 'date', 'sport'],
        relations: { belongsTo: ['Coach'], hasMany: ['Attendance'] }
      },
      Attendance: {
        fields: { memberId: 'string', sessionId: 'string', checkIn: 'DateTime', checkOut: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'sessionId'],
        relations: { belongsTo: ['Member', 'Session'] }
      },
      Payment: {
        fields: { memberId: 'string', membershipId: 'string?', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'status'],
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['Member registers and selects a membership plan', 'Coach schedules training sessions', 'Member attends sessions and checks in', 'Attendance is tracked for each session', 'Membership is renewed periodically'],
    endpoints: ['GET    /api/members                          ?status=&search=&page=&limit=', 'POST   /api/members                          { name, email, phone, dateOfBirth? }', 'POST   /api/memberships                     { memberId, type, startDate, endDate, price }', 'POST   /api/sessions                        { coachId, sport, date, startTime, endTime, capacity }', 'POST   /api/attendance                      { memberId, sessionId }', 'POST   /api/payments                        { memberId, amount, method }', 'GET    /api/dashboard/sportsclub-summary'],
    metrics: ['Active members', 'Session attendance rate', 'Membership retention', 'Revenue per member', 'Session utilization'],
    genericFeatures: ['Member Management', 'Membership Plans', 'Session Scheduling', 'Attendance Tracking', 'Payment & Renewal'],
  },

  volunteer_platform: {
    name: 'Volunteer Platform / Platform Relawan',
    actors: ['Volunteer', 'Organizer', 'Admin'],
    entities: {
      Project: {
        fields: { organizerId: 'string', title: 'string', description: 'string?', category: 'string', location: 'string', startDate: 'DateTime', endDate: 'DateTime?', volunteersNeeded: 'Int', status: 'ProjStatus @default(DRAFT)', createdAt: 'DateTime @default(now())' },
        enums: { ProjStatus: ['DRAFT', 'OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['organizerId', 'category', 'status', 'startDate'],
        relations: { belongsTo: ['Organizer'], hasMany: ['Shift'] }
      },
      Volunteer: {
        fields: { name: 'string', email: 'string @unique', phone: 'string', skills: 'string (JSON)?', availability: 'string?', totalHours: 'Float @default(0)', status: 'string @default("ACTIVE")', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Shift', 'Hours'] }
      },
      Shift: {
        fields: { projectId: 'string', volunteerId: 'string?', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', slotsNeeded: 'Int', slotsFilled: 'Int @default(0)', status: 'string @default("OPEN")', createdAt: 'DateTime @default(now())' },
        indexes: ['projectId', 'volunteerId', 'date'],
        relations: { belongsTo: ['Project', 'Volunteer'] }
      },
      Hours: {
        fields: { volunteerId: 'string', projectId: 'string', shiftId: 'string', hoursWorked: 'Float', verifiedBy: 'string?', verifiedAt: 'DateTime?', status: 'string @default("PENDING")', createdAt: 'DateTime @default(now())' },
        indexes: ['volunteerId', 'projectId', 'status'],
        relations: { belongsTo: ['Volunteer', 'Project', 'Shift'] }
      },
      Impact: {
        fields: { projectId: 'string', totalVolunteers: 'Int', totalHours: 'Float', beneficiaries: 'Int?', outcome: 'string?', calculatedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Project'] }
      },
    },
    flows: ['Organizer posts a volunteer project with shifts', 'Volunteer browses and applies for open shifts', 'Volunteer serves during assigned shifts', 'Hours are verified by organizer', 'Impact report generated after project completion'],
    endpoints: ['GET    /api/projects                         ?category=&status=&location=&page=&limit=', 'POST   /api/projects                         { organizerId, title, description?, category, location, startDate, endDate?, volunteersNeeded }', 'POST   /api/shifts                           { projectId, date, startTime, endTime, slotsNeeded }', 'POST   /api/apply                            { volunteerId, shiftId }', 'POST   /api/hours                            { volunteerId, projectId, shiftId, hoursWorked }', 'PATCH  /api/hours/:id/verify                 { verifiedBy }', 'GET    /api/dashboard/volunteer-summary'],
    metrics: ['Volunteers recruited', 'Total hours served', 'Project completion rate', 'Volunteer retention', 'Community impact'],
    genericFeatures: ['Project Management', 'Shift Scheduling', 'Volunteer Matching', 'Hours Tracking', 'Impact Report'],
  },

  alumni_network: {
    name: 'Alumni Network / Jaringan Alumni',
    actors: ['Alumni', 'Admin'],
    entities: {
      Member: {
        fields: { name: 'string', email: 'string @unique', phone: 'string?', graduationYear: 'Int', major: 'string', faculty: 'string', company: 'string?', position: 'string?', location: 'string?', photo: 'string?', linkedInUrl: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['email', 'graduationYear', 'major', 'faculty'],
        relations: { hasMany: ['Event', 'Job', 'Donation'] }
      },
      Event: {
        fields: { organizerId: 'string', title: 'string', description: 'string?', date: 'DateTime', location: 'string', type: 'string @default("SOCIAL")', maxAttendees: 'Int?', status: 'string @default("UPCOMING")', createdAt: 'DateTime @default(now())' },
        indexes: ['organizerId', 'date', 'type', 'status'],
        relations: { belongsTo: ['Member'] }
      },
      Job: {
        fields: { memberId: 'string', company: 'string', title: 'string', description: 'string?', location: 'string?', type: 'string @default("FULL_TIME")', salary: 'string?', isActive: 'Boolean @default(true)', postedAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'company', 'isActive'],
        relations: { belongsTo: ['Member'] }
      },
      Donation: {
        fields: { memberId: 'string', amount: 'Float', campaign: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['memberId', 'campaign'],
        relations: { belongsTo: ['Member'] }
      },
      Directory: {
        fields: { memberId: 'string', isPublic: 'Boolean @default(true)', updatedAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Member'] }
      },
    },
    flows: ['Alumni registers and updates personal profile', 'Alumni connects with other alumni in directory', 'Alumni creates or joins alumni events', 'Alumni posts job opportunities for fellow alumni', 'Alumni contributes donations to alma mater'],
    endpoints: ['GET    /api/members                          ?graduationYear=&major=&faculty=&search=&page=&limit=', 'POST   /api/members                          { name, email, phone?, graduationYear, major, faculty }', 'PATCH  /api/members/:id                       { company?, position?, photo?, linkedInUrl? }', 'GET    /api/events                            ?type=&status=&dateFrom=&page=&limit=', 'POST   /api/events                            { organizerId, title, description?, date, location, type }', 'POST   /api/jobs                             { memberId, company, title, description?, type }', 'POST   /api/donations                        { memberId, amount, campaign }', 'GET    /api/dashboard/alumni-summary'],
    metrics: ['Registered alumni', 'Event attendance', 'Job postings filled', 'Donation amount', 'Alumni engagement rate'],
    genericFeatures: ['Alumni Registry', 'Directory & Networking', 'Event Management', 'Job Board', 'Donations & Giving'],
  },

  spa: {
    name: 'Spa / Spa & Wellness',
    actors: ['Customer', 'Therapist', 'Admin'],
    entities: {
      Service: {
        fields: { name: 'string @unique', description: 'string?', duration: 'Int', price: 'Float', category: 'string', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['category', 'isActive'],
        relations: { hasMany: ['Appointment'] }
      },
      Appointment: {
        fields: { customerId: 'string', therapistId: 'string?', serviceId: 'string', date: 'DateTime', startTime: 'DateTime', endTime: 'DateTime', status: 'ApptStatus @default(PENDING)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { ApptStatus: ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'] },
        indexes: ['customerId', 'therapistId', 'date', 'status'],
        relations: { belongsTo: ['Customer', 'Therapist', 'Service'] }
      },
      Therapist: {
        fields: { name: 'string', phone: 'string @unique', email: 'string?', specialization: 'string?', isActive: 'Boolean @default(true)', workingHours: 'string (JSON)?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Appointment'] }
      },
      Product: {
        fields: { name: 'string', description: 'string?', price: 'Float', stock: 'Int @default(0)', category: 'string', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Payment'] }
      },
      Payment: {
        fields: { appointmentId: 'string', customerId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['appointmentId', 'status'],
        relations: { belongsTo: ['Appointment', 'Customer'] }
      },
    },
    flows: ['Customer books a spa service with preferred therapist', 'Customer arrives and checks in for appointment', 'Therapist provides the spa treatment', 'Customer pays after service is completed', 'Customer leaves a review for future guests'],
    endpoints: ['GET    /api/services                         ?category=&isActive=', 'POST   /api/appointments                    { customerId, therapistId?, serviceId, date, startTime }', 'GET    /api/appointments                    ?customerId=&status=&dateFrom=&page=&limit=', 'PATCH  /api/appointments/:id/status          { status }', 'POST   /api/payments                        { appointmentId, customerId, amount, method }', 'GET    /api/dashboard/spa-summary'],
    metrics: ['Appointments per day', 'Therapist utilization', 'Revenue per service', 'Customer satisfaction', 'Booking lead time'],
    genericFeatures: ['Manajemen Layanan', 'Booking & Jadwal', 'Therapist Management', 'Pembayaran', 'Rating & Review'],
  },

  tailoring: {
    name: 'Tailoring / Penjahit',
    actors: ['Customer', 'Tailor', 'Admin'],
    entities: {
      Order: {
        fields: { orderNumber: 'string @unique', customerId: 'string', tailorId: 'string', type: 'string @default("CUSTOM")', description: 'string', status: 'OrderStatus @default(PENDING)', totalPrice: 'Float', depositAmount: 'Float @default(0)', dueDate: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())', updatedAt: 'DateTime @updatedAt' },
        enums: { OrderStatus: ['PENDING', 'MEASURED', 'CUTTING', 'SEWING', 'FITTING', 'COMPLETED', 'DELIVERED', 'CANCELLED'] },
        indexes: ['orderNumber', 'customerId', 'tailorId', 'status'],
        relations: { belongsTo: ['Customer', 'Tailor'], hasMany: ['Measurement', 'Garment', 'Payment'] }
      },
      Measurement: {
        fields: { orderId: 'string', customerId: 'string', chest: 'Float?', waist: 'Float?', hips: 'Float?', shoulders: 'Float?', armLength: 'Float?', legLength: 'Float?', neck: 'Float?', notes: 'string?', recordedAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'customerId'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
      Fabric: {
        fields: { name: 'string', color: 'string', pattern: 'string?', pricePerMeter: 'Float', stock: 'Float @default(0)', supplier: 'string?', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['name', 'color']
      },
      Garment: {
        fields: { orderId: 'string', name: 'string', fabricId: 'string?', quantity: 'Int @default(1)', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Order'] }
      },
      Payment: {
        fields: { orderId: 'string', customerId: 'string', amount: 'Float', type: 'string @default("DEPOSIT")', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'type', 'status'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
    },
    flows: ['Customer consults with tailor about desired garment', 'Tailor takes customer measurements', 'Tailor cuts fabric and sews the garment', 'Customer comes for fitting — adjustments made', 'Garment is completed and delivered to customer'],
    endpoints: ['POST   /api/orders                          { customerId, tailorId, type, description, dueDate? }', 'GET    /api/orders                           ?status=&customerId=&page=&limit=', 'PATCH  /api/orders/:id/status                { status }', 'POST   /api/measurements                    { orderId, customerId, chest?, waist?, shoulders? }', 'POST   /api/payments                        { orderId, customerId, amount, type, method }', 'GET    /api/dashboard/tailoring-summary'],
    metrics: ['Orders per month', 'Average completion time', 'Customer satisfaction', 'Revenue per order', 'Repeat customer rate'],
    genericFeatures: ['Manajemen Order', 'Pengukuran', 'Produksi Jahit', 'Fitting', 'Pembayaran'],
  },

  laundry_delivery: {
    name: 'Laundry Delivery / Laundry Antar Jemput',
    actors: ['Customer', 'Driver', 'Staff', 'Admin'],
    entities: {
      Order: {
        fields: { orderNumber: 'string @unique', customerId: 'string', driverId: 'string?', status: 'OrderStatus @default(PENDING)', totalWeight: 'Float @default(0)', totalPrice: 'Float @default(0)', pickupAddress: 'string', deliveryAddress: 'string', pickupTime: 'DateTime?', deliveryTime: 'DateTime?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        enums: { OrderStatus: ['PENDING', 'PICKED_UP', 'WASHING', 'DRYING', 'IRONING', 'PACKING', 'DELIVERING', 'DELIVERED', 'CANCELLED'] },
        indexes: ['orderNumber', 'customerId', 'driverId', 'status'],
        relations: { belongsTo: ['Customer', 'Driver'], hasMany: ['Item', 'Payment', 'Tracking'] }
      },
      Item: {
        fields: { orderId: 'string', name: 'string', quantity: 'Int', weight: 'Float?', notes: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId'],
        relations: { belongsTo: ['Order'] }
      },
      Driver: {
        fields: { name: 'string', phone: 'string @unique', vehicle: 'string', isAvailable: 'Boolean @default(true)', currentLat: 'Float?', currentLng: 'Float?', createdAt: 'DateTime @default(now())' },
        relations: { hasMany: ['Order'] }
      },
      Tracking: {
        fields: { orderId: 'string', driverId: 'string?', status: 'string', location: 'string?', timestamp: 'DateTime @default(now())' },
        indexes: ['orderId', 'timestamp'],
        relations: { belongsTo: ['Order', 'Driver'] }
      },
      Payment: {
        fields: { orderId: 'string', customerId: 'string', amount: 'Float', method: 'string', status: 'string @default("PENDING")', paidAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['orderId', 'status'],
        relations: { belongsTo: ['Order', 'Customer'] }
      },
    },
    flows: ['Customer orders laundry pickup via app', 'Driver picks up laundry from customer address', 'Staff washes, dries, and irons the laundry', 'Driver delivers clean laundry back to customer', 'Customer pays for the service'],
    endpoints: ['POST   /api/orders                          { customerId, pickupAddress, deliveryAddress, notes? }', 'GET    /api/orders                           ?status=&customerId=&page=&limit=', 'PATCH  /api/orders/:id/status                { status }', 'POST   /api/items                           { orderId, name, quantity, weight?, notes? }', 'PATCH  /api/orders/:id/assign-driver         { driverId }', 'POST   /api/tracking                        { orderId, driverId?, status, location? }', 'POST   /api/payments                        { orderId, customerId, amount, method }', 'GET    /api/dashboard/laundry-summary'],
    metrics: ['Orders per day', ['Orders per day', 'Average processing time'], 'Driver utilization', 'Customer satisfaction', 'Average order value'],
    genericFeatures: ['Order Management', 'Pickup & Delivery', 'Laundry Processing', 'Driver Tracking', 'Payment Collection'],
  },

  grocery: {
    name: 'Grocery / Toko Sembako',
    actors: ['Customer', 'Cashier', 'Manager'],
    entities: {
      Product: {
        fields: { name: 'string', barcode: 'string @unique', categoryId: 'string', unit: 'string', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(10)', isActive: 'Boolean @default(true)', expiryDate: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['barcode', 'categoryId', 'stock'],
        relations: { belongsTo: ['Category'], hasMany: ['Stock', 'Sale'] }
      },
      Category: {
        fields: { name: 'string @unique', description: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Product'] }
      },
      Stock: {
        fields: { productId: 'string', supplierId: 'string', quantity: 'Int', purchasePrice: 'Float', batchNumber: 'string?', receivedAt: 'DateTime @default(now())' },
        indexes: ['productId', 'supplierId'],
        relations: { belongsTo: ['Product', 'Supplier'] }
      },
      Sale: {
        fields: { productId: 'string', customerId: 'string?', quantity: 'Int', pricePerUnit: 'Float', totalPrice: 'Float', cashierId: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['productId', 'cashierId', 'soldAt'],
        relations: { belongsTo: ['Product', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
    },
    flows: ['Manager stocks products from suppliers', 'Products are displayed with prices', 'Cashier scans items and processes sale', 'Stock is automatically decremented after sale', 'Manager reorders when stock runs low'],
    endpoints: ['GET    /api/products                         ?categoryId=&search=&isActive=&page=&limit=', 'POST   /api/products                         { name, barcode, categoryId, unit, price, minStock }', 'POST   /api/stock                           { productId, supplierId, quantity, purchasePrice }', 'POST   /api/sales                           { productId, quantity, pricePerUnit, totalPrice, cashierId }', 'GET    /api/sales                           ?dateFrom=&dateTo=&cashierId=&page=&limit=', 'POST   /api/suppliers                       { name, contact, phone }', 'GET    /api/dashboard/grocery-summary'],
    metrics: ['Daily sales', 'Stock turnover rate', 'Expired product loss', 'Gross margin %', 'Supplier reliability'],
    genericFeatures: ['Manajemen Produk', 'Stok & Supplier', 'POS Kasir', 'Penjualan Harian', 'Laporan Laba'],
  },

  convenience_store: {
    name: 'Convenience Store / Toko Kelontong',
    actors: ['Cashier', 'Manager', 'Owner'],
    entities: {
      Product: {
        fields: { name: 'string', barcode: 'string @unique', category: 'string', unit: 'string', price: 'Float', stock: 'Int @default(0)', minStock: 'Int @default(5)', isActive: 'Boolean @default(true)', createdAt: 'DateTime @default(now())' },
        indexes: ['barcode', 'category', 'stock'],
        relations: { hasMany: ['Sale', 'Stock'] }
      },
      Sale: {
        fields: { productId: 'string', quantity: 'Int', pricePerUnit: 'Float', totalPrice: 'Float', cashierId: 'string', paymentMethod: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['cashierId', 'soldAt'],
        relations: { belongsTo: ['Product', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Stock: {
        fields: { productId: 'string', supplierId: 'string', quantity: 'Int', purchasePrice: 'Float', receivedAt: 'DateTime @default(now())' },
        indexes: ['productId', 'supplierId'],
        relations: { belongsTo: ['Product', 'Supplier'] }
      },
      Shift: {
        fields: { cashierId: 'string', startTime: 'DateTime', endTime: 'DateTime?', totalSales: 'Float @default(0)', status: 'string @default("ACTIVE")', notes: 'string?', createdAt: 'DateTime @default(now())' },
        relations: { belongsTo: ['Cashier'], hasMany: ['Sale'] }
      },
    },
    flows: ['Cashier starts shift and opens register', 'Customer buys items — cashier scans and processes payment', 'Cashier handles cash or digital payment', 'Stock is updated after each sale', 'Manager reconciles sales and reorders stock'],
    endpoints: ['GET    /api/products                         ?category=&search=&isActive=&page=&limit=', 'POST   /api/sales                           { productId, quantity, pricePerUnit, totalPrice, cashierId, paymentMethod }', 'GET    /api/sales                           ?dateFrom=&dateTo=&cashierId=&page=&limit=', 'POST   /api/stock                           { productId, supplierId, quantity, purchasePrice }', 'POST   /api/shifts                          { cashierId }', 'PATCH  /api/shifts/:id/close                { totalSales, notes? }', 'GET    /api/dashboard/convenience-summary'],
    metrics: ['Daily transactions', 'Average transaction value', 'Stock turnover', 'Cashier performance', 'Gross margin'],
    genericFeatures: ['Manajemen Produk', ['Manajemen Produk', 'POS Kasir'], 'Shift Management', 'Stok & Supplier', 'Laporan Harian'],
  },

  pharmacy_retail: {
    name: 'Pharmacy Retail / Apotek Retail',
    actors: ['Pharmacist', 'Cashier', 'Manager'],
    entities: {
      Medicine: {
        fields: { name: 'string', sku: 'string @unique', category: 'string', price: 'Float', requiresPrescription: 'Boolean @default(false)', stock: 'Int @default(0)', minStock: 'Int @default(10)', expiryDate: 'DateTime?', manufacturer: 'string?', createdAt: 'DateTime @default(now())' },
        indexes: ['sku', 'category', 'stock'],
        relations: { hasMany: ['Prescription', 'Sale', 'Stock'] }
      },
      Prescription: {
        fields: { customerName: 'string', doctorName: 'string?', medicineId: 'string', dosage: 'string', quantity: 'Int', pharmacistId: 'string', status: 'string @default("PENDING")', notes: 'string?', filledAt: 'DateTime?', createdAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'status'],
        relations: { belongsTo: ['Medicine', 'Pharmacist'] }
      },
      Sale: {
        fields: { medicineId: 'string', prescriptionId: 'string?', customerName: 'string?', quantity: 'Int', totalPrice: 'Float', paymentMethod: 'string', cashierId: 'string', soldAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'cashierId', 'soldAt'],
        relations: { belongsTo: ['Medicine', 'Cashier'] }
      },
      Supplier: {
        fields: { name: 'string', contact: 'string', phone: 'string', email: 'string?', address: 'string?', isActive: 'Boolean @default(true)' },
        relations: { hasMany: ['Stock'] }
      },
      Stock: {
        fields: { medicineId: 'string', supplierId: 'string', batchNumber: 'string', quantity: 'Int', purchasePrice: 'Float', receivedAt: 'DateTime @default(now())' },
        indexes: ['medicineId', 'supplierId'],
        relations: { belongsTo: ['Medicine', 'Supplier'] }
      },
    },
    flows: ['Pharmacist receives medicine shipment from supplier', 'Customer brings prescription — pharmacist verifies', 'Pharmacist dispenses medicine — cashier processes sale', 'Stock is updated after each transaction', 'Manager reorders when stock reaches minimum level'],
    endpoints: ['GET    /api/medicines                        ?category=&requiresPrescription=&search=&page=&limit=', 'POST   /api/medicines                        { name, sku, category, price, requiresPrescription, minStock }', 'POST   /api/prescriptions                    { customerName, doctorName?, medicineId, dosage, quantity, pharmacistId }', 'POST   /api/sales                           { medicineId, prescriptionId?, customerName?, quantity, totalPrice, paymentMethod, cashierId }', 'POST   /api/stock                           { medicineId, supplierId, batchNumber, quantity, purchasePrice }', 'GET    /api/dashboard/pharmacy-retail-summary'],
    metrics: ['Daily revenue', 'Prescriptions filled', 'Stock turnover', 'Expired stock loss', 'Customer transactions'],
    genericFeatures: ['Manajemen Obat', 'Resep & Dispensing', 'POS Retail', 'Stok & Supplier', 'Laporan Apotek'],
  }
'''


# ============================================================
# All 45 new DOMAIN_KEYWORDS entries
# ============================================================
new_keywords = r'''
  pharmacy: ['pharmacy', 'apotek', 'obat', 'medicine', 'resep', 'prescription', 'drugstore', 'farmasi'],
  laboratory: ['laboratory', 'lab', 'laboratorium', 'test lab', 'sample', 'hasil lab', 'medical check'],
  telemedicine: ['telemedicine', 'telehealth', 'dokter online', 'konsultasi online', 'teleconsultation', 'video call dokter'],
  tutoring: ['tutoring', 'les', 'bimbel', 'privat', 'tutor', 'bimbingan belajar', 'les private'],
  bootcamp: ['bootcamp', 'coding bootcamp', 'pelatihan intensif', 'programming course', 'intensive training'],
  school_management: ['school', 'sekolah', 'madrasah', 'siswa', 'guru', 'kelas', 'rapor', 'akademik'],
  lms: ['lms', 'learning management', 'e-learning', 'moodle', 'kelas online', 'platform belajar'],
  personal_finance: ['personal finance', 'keuangan pribadi', 'budget', 'anggaran', 'pengeluaran', 'pemasukan'],
  cooperative: ['cooperative', 'koperasi', 'simpan pinjam', 'anggota koperasi', 'shu'],
  insurance: ['insurance', 'asuransi', 'polis', 'premi', 'klaim', 'adjuster'],
  warehouse: ['warehouse', 'gudang', 'bin', 'stock movement', 'receiving', 'shipping', 'inventory gudang'],
  cold_chain: ['cold chain', 'rantai dingin', 'suhu', 'temperature', 'sensor suhu', 'cold storage'],
  freight: ['freight', 'kargo', 'pengiriman barang', 'logistik', 'shipping cargo', 'freight forwarding'],
  homestay: ['homestay', 'penginapan', 'guest house', 'sewa rumah', 'home stay', 'inap'],
  villa_rental: ['villa', 'sewa villa', 'villa rental', 'liburan', 'holiday villa', 'villa'],
  guest_house: ['guest house', 'losmen', 'penginapan murah', 'inn', 'lodging'],
  resort: ['resort', 'resort wisata', 'hotel resort', 'liburan resort', 'penginapan mewah', 'vacation resort'],
  help_desk: ['help desk', 'ticket', 'support ticket', 'customer support', 'helpdesk', 'layanan pelanggan'],
  loyalty_program: ['loyalty program', 'poin', 'reward', 'member point', 'loyalitas', 'program loyalitas'],
  sales_pipeline: ['sales pipeline', 'pipeline sales', 'deal', 'lead management', 'prospek', 'sales tracking'],
  project_management: ['project management', 'manajemen proyek', 'project', 'gantt', 'timeline proyek', 'task project'],
  task_management: ['task management', 'todo', 'to-do', 'tugas', 'task', 'productivity', 'manajemen tugas'],
  note_taking: ['note taking', 'catatan', 'notebook', 'notes', 'mencatat', 'note app'],
  okr_tracking: ['okr', 'objective', 'key result', 'kpi', 'target', 'kinerja', 'performance tracking'],
  content_subscription: ['content subscription', 'langganan konten', 'creator', 'subscriber', 'premium content'],
  podcast_platform: ['podcast', 'podcast platform', 'episode', 'host podcast', 'podcaster', 'audio streaming'],
  template_marketplace: ['template marketplace', 'template', 'marketplace template', 'jual template', 'download template'],
  fishery: ['fishery', 'perikanan', 'ikan', 'tambak', 'kolam ikan', 'budidaya ikan', 'nelayan'],
  plantation: ['plantation', 'perkebunan', 'kebun', 'sawah', 'tanaman', 'crop', 'lahan'],
  greenhouse: ['greenhouse', 'rumah kaca', 'hidroponik', 'hydroponic', 'sensor greenhouse'],
  car_wash: ['car wash', 'cuci mobil', 'cuci kendaraan', 'car detailing', 'automotive wash'],
  motorcycle_workshop: ['motorcycle workshop', 'bengkel motor', 'service motor', 'tune up motor', 'sparepart motor'],
  tire_shop: ['tire shop', 'ban', 'toko ban', 'ganti ban', 'spooring', 'balancing ban'],
  rental_management: ['rental management', 'manajemen sewa', 'sewa properti', 'rental unit', 'tenant management'],
  real_estate_agency: ['real estate', 'properti', 'agen properti', 'jual rumah', 'real estate agent', 'listing properti'],
  strata_management: ['strata management', 'apartment management', 'manajemen apartemen', 'ipp', 'spp apartemen'],
  sports_club: ['sports club', 'klub olahraga', 'futsal', 'badminton', 'tenis', 'olahraga', 'gym club'],
  volunteer_platform: ['volunteer', 'relawan', 'sukarelawan', 'volunteering', 'kerja bakti', 'social project'],
  alumni_network: ['alumni', 'alumni network', 'jaringan alumni', 'alumni sekolah', 'alumni universitas'],
  spa: ['spa', 'wellness', 'massage', 'pijat', 'beauty spa', 'perawatan tubuh'],
  tailoring: ['tailoring', 'penjahit', 'jahit', 'custom suit', 'kostum', 'tailor'],
  laundry_delivery: ['laundry', 'laundry delivery', 'cuci sepatu', 'laundry antar', 'binatu', 'cuci'],
  grocery: ['grocery', 'sembako', 'toko kelontong', 'bahan pokok', 'sembako murah', 'grosir'],
  convenience_store: ['convenience store', 'toko kelontong', 'minimarket', 'warung', 'retail kecil'],
  pharmacy_retail: ['pharmacy retail', 'apotek retail', 'obat bebas', 'toko obat', 'drugstore']
'''


# ============================================================
# All 45 new domainHints entries
# ============================================================
new_hints = r'''
      pharmacy: ['Pharmacist dapat menambah obat baru dengan SKU, kategori, harga, dan stok awal', 'Sistem harus memvalidasi SKU unik sebelum menyimpan obat', 'Resep dari dokter divalidasi oleh apoteker sebelum dispensing', 'Stok otomatis berkurang saat obat dijual atau didispense', 'Low stock alert muncul ketika stok di bawah batas minimum', 'Validasi: dosis dan kuantitas resep harus masuk akal (tidak melebihi maksimum)', 'Error message: \"Stok tidak mencukupi. Tersedia: {qty}\"', 'Edge case: obat mendekati expired — beri peringatan saat dispensing'],
      laboratory: ['LabTech dapat menambah test baru dengan kategori, harga, dan persiapan', 'Sample harus dilabel dengan benar dan ditracking dari koleksi hingga hasil', 'Test dapat memiliki beberapa parameter hasil dengan reference range', 'Hasil abnormal otomatis ditandai untuk review dokter', 'Sistem mencatat timestamp setiap perubahan status sample', 'Validasi: sample harus sampai di lab sebelum hasil bisa dimasukkan', 'Error message: \"Sample tidak ditemukan\"', 'Edge case: sample rusak atau hilang — catat sebagai reject dan minta sample baru'],
      telemedicine: ['Dokter dapat mengatur jadwal ketersediaan untuk konsultasi online', 'Konsultasi dimulai tepat waktu sesuai jadwal booking', 'Sistem mencatat seluruh sesi konsultasi termasuk resep', 'Resep dikirim ke pasien secara digital setelah konsultasi', 'Riwayat medis pasien diperbarui setelah setiap konsultasi', 'Validasi: durasi konsultasi tidak boleh melebihi slot yang ditentukan', 'Error message: \"Dokter sedang tidak tersedia. Pilih jadwal lain\"', 'Edge case: koneksi terputus saat konsultasi — fitur reconnection otomatis'],
      tutoring: ['Tutor dapat menentukan tarif per jam dan jadwal mengajar', 'Sesi tutoring terjadwal mengikat antara tutor dan siswa', 'Sistem mencatat kehadiran dan durasi sesi', 'Pekerjaan rumah diberikan dan dinilai oleh tutor', 'Laporan perkembangan siswa dikirim ke orang tua secara periodik', 'Validasi: jadwal tutor tidak boleh bentrok', 'Error message: \"Jadwal tutor sudah terisi. Pilih waktu lain\"', 'Edge case: tutor tiba-tiba sakit — cari tutor pengganti atau reschedule'],
      bootcamp: ['Program bootcamp memiliki kurikulum terstruktur dengan modul berurutan', 'Mentor dapat membuat assignment dengan deadline dan kriteria penilaian', 'Siswa mengumpulkan tugas dan mentor memberikan skor serta feedback', 'Progress siswa terlihat di dashboard untuk monitoring', 'Sertifikat diberikan setelah semua modul selesai', 'Validasi: submission harus sebelum deadline', 'Error message: \"Pengumpulan sudah melewati deadline\"', 'Edge case: siswa tertinggal modul karena alasan khusus — beri perpanjangan waktu'],
      school_management: ['Admin dapat mendaftarkan siswa baru dan assign ke kelas', 'Absensi dicatat setiap hari untuk setiap siswa', 'Nilai dimasukkan per mata pelajaran per semester', 'Jadwal pelajaran diatur per kelas per hari', 'Rapor dihasilkan dari gabungan nilai dan absensi', 'Validasi: nomor induk siswa harus unik', 'Error message: \"NISN sudah terdaftar\"', 'Edge case: siswa pindah kelas di tengah semester — data tetap lengkap'],
      lms: ['Instructor dapat membuat course dengan lesson dan quiz', 'Learner dapat mengakses materi sesuai urutan yang ditentukan', 'Quiz menilai pemahaman dengan passing score tertentu', 'Progress disimpan per user per course dan lesson', 'Sertifikat diterbitkan setelah course selesai dengan passing grade', 'Validasi: learner harus menyelesaikan lesson sebelum quiz', 'Error message: \"Selesaikan semua lesson sebelum mengakses quiz\"', 'Edge case: learner ingin mengulang quiz — gunakan attempt terbaik'],
      personal_finance: ['User dapat mencatat transaksi pemasukan dan pengeluaran setiap hari', 'Transaksi otomatis dikategorikan berdasarkan jenis dan deskripsi', 'Budget ditentukan per kategori per periode (bulanan)', 'Sistem menampilkan perbandingan realisasi vs budget', 'Report bulanan menunjukkan ringkasan keuangan', 'Validasi: nominal transaksi harus lebih dari 0', 'Error message: \"Budget telah melebihi batas untuk kategori ini\"', 'Edge case: transaksi berulang bulanan — set recurrence pattern'],
      cooperative: ['Anggota baru mendaftar dan mulai menabung secara teratur', 'Pinjaman diajukan dengan jumlah, bunga, dan tenor tertentu', 'Setiap pinjaman diangsur secara bulanan dengan jadwal tetap', 'Sistem menghitung otomatis sisa pinjaman dan bunga berjalan', 'SHU/Dividen dibagikan tahunan berdasarkan simpanan dan transaksi', 'Validasi: jumlah pinjaman tidak boleh melebihi saldo simpanan * 3', 'Error message: \"Pinjaman melebihi batas maksimal\"', 'Edge case: anggota menunggak angsuran — sistem hitung denda otomatis'],
      insurance: ['Client mengajukan permohonan polis dengan data lengkap', 'Agent melakukan underwriting dan menentukan risiko', 'Premi dibayar sesuai jadwal — status polis menjadi aktif', 'Klaim diajukan dengan dokumen pendukung lengkap', 'Adjuster menyelidiki validitas klaim sebelum settlement', 'Validasi: premi harus dibayar sebelum polis bisa aktif', 'Error message: \"Dokumen klaim tidak lengkap\"', 'Edge case: klaim diajukan setelah polis expired — ditolak otomatis'],
      warehouse: ['Staff menerima barang dan mencatat di sistem dengan quantity dan bin', 'Barang disimpan di bin location yang sesuai dengan kategorinya', 'Picking barang dilakukan berdasarkan FIFO atau FEFO', 'Packing dan shipping dicatat dengan nomor referensi', 'Manager dapat melihat qty stok per produk dan per bin', 'Validasi: bin harus punya sisa kapasitas sebelum menempatkan barang', 'Error message: \"Bin sudah penuh. Pilih bin lain\"', 'Edge case: 2 staff melakukan picking barang yang sama — pakai locking system'],
      cold_chain: ['Operator memuat produk yang sensitif suhu ke dalam kendaraan', 'Sensor suhu aktif selama pengiriman dan mencatat secara real-time', 'Sistem mengirim alert jika suhu melebihi threshold yang ditentukan', 'Semua log suhu tersimpan untuk audit trail', 'Pengiriman diverifikasi setelah tiba dengan cek log suhu', 'Validasi: suhu harus dalam range yang ditentukan produk', 'Error message: \"Suhu melebihi batas aman\"', 'Edge case: sensor mati di tengah perjalanan — gunakan data dari sensor cadangan'],
      freight: ['Shipper meminta quote pengiriman dengan detail berat dan tujuan', 'Carrier memberikan harga — shipper konfirmasi booking', 'Carrier pickup barang dari shipper dan catat di sistem', 'Tracking event diperbarui di setiap tahap perjalanan', 'Barang diterima dan dikonfirmasi oleh penerima', 'Validasi: berat tidak boleh melebihi kapasitas kendaraan', 'Error message: \"Berat melebihi kapasitas maksimal\"', 'Edge case: cuaca buruk menyebabkan delay — update ETA dan notifikasi'],
      homestay: ['Host dapat mendaftarkan properti dengan detail dan harga', 'Guest mencari dan booking properti untuk tanggal tertentu', 'Booking mengunci kalender untuk tanggal yang dipilih', 'Check-in dan check-out dicatat oleh host', 'Pembayaran diproses setelah check-in atau sesuai kebijakan', 'Validasi: check-out harus setelah check-in', 'Error message: \"Tanggal sudah dibooking. Pilih tanggal lain\"', 'Edge case: guest tidak datang (no-show) — deposit tidak dikembalikan'],
      villa_rental: ['Owner dapat list villa dengan harga per malam dan fasilitas', 'Guest booking villa dan bayar deposit untuk konfirmasi', 'Sisa pembayaran dilakukan saat check-in', 'Owner inspeksi villa setelah guest check-out', 'Guest memberikan review setelah masa sewa selesai', 'Validasi: deposit minimal 50% dari total sewa', 'Error message: \"Deposit belum dibayar. Booking tidak dapat dikonfirmasi\"', 'Edge case: guest merusak properti — potong dari deposit sesuai kebijakan'],
      guest_house: ['Receptionist mencatat reservasi kamar untuk guest', 'Kamar dicek ketersediaannya sebelum booking dikonfirmasi', 'Guest check-in dan diberikan akses kamar', 'Guest dapat request layanan tambahan seperti laundry', 'Check-out dan pembayaran selesai dalam satu proses', 'Validasi: kamar harus available untuk tanggal tersebut', 'Error message: \"Kamar tidak tersedia untuk tanggal yang dipilih\"', 'Edge case: guest ingin extended stay — cek availability'],
      resort: ['Guest booking kamar resort untuk liburan', 'Resepsionis check-in dan assign kamar sesuai preferensi', 'Guest menikmati fasilitas resort: kolam renang, spa, aktivitas', 'Staff menyediakan housekeeping dan room service', 'Guest check-out — semua tagihan diselesaikan', 'Validasi: jumlah tamu tidak boleh melebihi kapasitas kamar', 'Error message: \"Kamar penuh untuk tanggal tersebut\"', 'Edge case: guest sakit selama menginap — bantuan medis dipanggil'],
      help_desk: ['Customer dapat membuat tiket dengan kategori dan prioritas', 'Sistem assign tiket ke agent berdasarkan beban kerja', 'Agent merespon dan mengupdate status tiket', 'SLA dipantau untuk setiap tiket berdasarkan prioritas', 'Tiket ditutup setelah customer konfirmasi resolusi', 'Validasi: subject dan deskripsi tidak boleh kosong', 'Error message: \"Tiket dengan subjek yang sama sudah ada\"', 'Edge case: customer reopen tiket yang sudah closed — tiket original diaktifkan kembali'],
      loyalty_program: ['Member dapat mendaftar ke program loyalitas dengan data diri', 'Poin diperoleh dari setiap transaksi atau aktivitas tertentu', 'Member dapat menukarkan poin dengan reward yang tersedia', 'Tier member meningkat berdasarkan total poin atau transaksi', 'Poin memiliki masa berlaku dan akan expired jika tidak digunakan', 'Validasi: poin member harus cukup untuk menukar reward', 'Error message: \"Poin tidak mencukupi. Dibutuhkan {points} poin\"', 'Edge case: reward habis — tampilkan "stok habis" dan beri notifikasi saat tersedia'],
      sales_pipeline: ['Sales membuat lead baru dari berbagai sumber', 'Lead dikualifikasi melalui serangkaian aktivitas follow-up', 'Lead yang qualified dikonversi menjadi deal dengan value', 'Deal bergerak melalui pipeline stages hingga closing', 'Manager melihat forecast revenue berdasarkan pipeline', 'Validasi: value deal harus lebih dari 0', 'Error message: \"Lead sudah terdaftar dengan email yang sama\"', 'Edge case: deal loss di stage akhir — catat reason untuk analysis'],
      project_management: ['Manager membuat project dan menetapkan timeline', 'Task di-assign ke anggota tim dengan deadline dan prioritas', 'Anggota tim mengupdate status task dan mencatat hours', 'Milestone menjadi checkpoint progress project', 'Project selesai — semua deliverables terdokumentasi', 'Validasi: endDate harus setelah startDate', 'Error message: \"Tanggal selesai harus setelah tanggal mulai\"', 'Edge case: resource tidak tersedia — reassign task atau adjust timeline'],
      task_management: ['User membuat task baru dengan judul dan prioritas', 'Task dikelompokkan dalam list yang terorganisir', 'User dapat menambahkan label dan deadline', 'Task diupdate statusnya dari todo ke done', 'Task yang sudah lama selesai diarsipkan otomatis', 'Validasi: judul task tidak boleh kosong', 'Error message: \"Task gagal dibuat. Coba lagi\"', 'Edge case: user membuat subtask — gunakan parent-child relationship'],
      note_taking: ['User dapat membuat notebook untuk mengorganisir catatan', 'Catatan dibuat dengan rich text editor', 'Tag digunakan untuk mengkategorikan catatan', 'Pencarian full-text untuk menemukan catatan dengan cepat', 'Catatan dapat diarsipkan atau dihapus (soft delete)', 'Validasi: judul catatan tidak boleh kosong', 'Error message: \"Gagal menyimpan catatan\"', 'Edge case: 2 user edit catatan yang sama di waktu bersamaan — merge conflict handling'],
      okr_tracking: ['User atau manager menetapkan objective untuk periode tertentu', 'Setiap objective memiliki 3-5 key results yang terukur', 'Key result memiliki baseline, target, dan progress saat ini', 'Check-in dilakukan mingguan untuk update progress', 'Di akhir periode, skor OKR dihitung berdasarkan pencapaian KR', 'Validasi: target value harus di atas start value', 'Error message: \"Key result harus memiliki target yang terukur\"', 'Edge case: objective di tengah periode berubah prioritas — archive dan buat baru'],
      content_subscription: ['Creator membuat konten premium untuk subscriber', 'Plan langganan dibuat dengan harga dan benefit berbeda', 'Subscriber memilih plan dan membayar berlangganan', 'Konten eksklusif hanya bisa diakses subscriber aktif', 'Creator melihat analytics subscriber dan revenue', 'Validasi: pembayaran harus berhasil sebelum akses konten diberikan', 'Error message: \"Langganan tidak aktif. Perbarui pembayaran\"', 'Edge case: pembayaran gagal setelah akses diberikan — revoke akses hingga pembayaran sukses'],
      podcast_platform: ['Host merekam dan mengupload episode podcast', 'Episode dipublikasikan ke feed subscribers', 'Listener berlangganan podcast dan mendapatkan notifikasi episode baru', 'Setiap episode memiliki statistik: listens, durasi rata-rata, completion rate', 'Host mendapat revenue dari iklan atau donasi pendengar', 'Validasi: file audio harus dalam format yang didukung (MP3, AAC)', 'Error message: \"Format audio tidak didukung\"', 'Edge case: episode mengandung konten sensitif — beri peringatan sebelum diputar'],
      template_marketplace: ['Creator upload template dengan file dan preview', 'Template direview oleh admin sebelum dipublikasikan', 'Buyer mencari template berdasarkan kategori dan format', 'Pembelian memberikan akses download unlimited', 'Creator mendapat payout berdasarkan penjualan', 'Validasi: file template harus di bawah 100MB', 'Error message: \"File terlalu besar. Maksimal 100MB\"', 'Edge case: buyer tidak puas dengan kualitas — ajukan refund dalam 7 hari'],
      fishery: ['Petani menyiapkan kolam dan menebar benih ikan', 'Pakan diberikan secara terjadwal dengan jumlah yang tepat', 'Pertumbuhan ikan dimonitor secara berkala', 'Ikan dipanen saat mencapai berat target', 'Hasil panen dijual ke buyer dengan harga pasar', 'Validasi: jumlah pakan tidak boleh melebihi kapasitas kolam', 'Error message: \"Kolam tidak siap untuk penebaran\"', 'Edge case: ikan mati massal — investigasi penyebab dan catat kerugian'],
      plantation: ['Petani mempersiapkan lahan dan menanam bibit', 'Perawatan dilakukan secara rutin: pemupukan, penyiraman, pengendalian hama', 'Tanaman dipantau pertumbuhannya hingga siap panen', 'Panen dilakukan pada waktu yang tepat untuk kualitas optimal', 'Hasil panen dijual atau diolah lebih lanjut', 'Validasi: musim tanam harus sesuai dengan jenis tanaman', 'Error message: \"Bukan musim tanam yang tepat\"', 'Edge case: gagal panen karena cuaca buruk — klaim asuransi pertanian'],
      greenhouse: ['Petani menanam tanaman di lingkungan rumah kaca yang terkontrol', 'Sensor memonitor suhu, kelembaban, dan pH secara real-time', 'Sistem secara otomatis mengatur ventilasi dan irigasi', 'Tanaman dipanen saat mencapai kualitas prima', 'Hasil panen dijual langsung ke konsumen atau restoran', 'Validasi: sensor harus dikalibrasi secara berkala', 'Error message: \"Sensor tidak merespon. Periksa koneksi\"', 'Edge case: listrik padam — backup generator otomatis menyala'],
      car_wash: ['Customer datang dan memilih paket cuci yang diinginkan', 'Worker mencatat pesanan dan mulai proses pencucian', 'Mobil dicuci sesuai prosedur: exterior, interior, vacuum', 'Mobil dikeringkan dan diperiksa kualitasnya', 'Customer membayar dan menerima struk', 'Validasi: nomor plat kendaraan harus diisi', 'Error message: \"Nomor plat tidak valid\"', 'Edge case: customer request tambahan setelah cuci dimulai — sesuaikan harga dan waktu'],
      motorcycle_workshop: ['Customer datang dengan keluhan pada motornya', 'Mekanik mendiagnosa masalah dan memberikan estimasi biaya', 'Customer menyetujui estimasi — perbaikan dimulai', 'Spare part yang rusak diganti dengan yang baru', 'Motor selesai diperbaiki dan customer bayar', 'Validasi: estimasi biaya harus disetujui customer sebelum repair', 'Error message: \"Spare part tidak tersedia. Pesan terlebih dahulu\"', 'Edge case: biaya perbaikan membengkak — konfirmasi ulang ke customer'],
      tire_shop: ['Customer datang untuk cek kondisi ban', 'Teknisi memeriksa tekanan udara dan kedalaman alur ban', 'Ban yang aus diganti dengan yang baru sesuai ukuran', 'Ban baru di balancing dan spooring', 'Customer bayar dan kendaraan siap digunakan', 'Validasi: ukuran ban harus sesuai dengan spesifikasi kendaraan', 'Error message: \"Ukuran ban tidak tersedia\"', 'Edge case: customer mau ganti hanya 2 ban — infokan pentingnya keseimbangan ban'],
      rental_management: ['Owner mendaftarkan properti dan unit yang tersedia', 'Tenant menandatangani perjanjian sewa untuk unit tertentu', 'Pembayaran sewa dilakukan bulanan dan dicatat sistem', 'Perbaikan diajukan oleh tenant dan ditindaklanjuti owner', 'Kontrak sewa diperpanjang atau diakhiri sesuai ketentuan', 'Validasi: endDate lease harus setelah startDate', 'Error message: \"Unit sudah disewa untuk periode tersebut\"', 'Edge case: tenant telat bayar 3 bulan berturut-turut — proses eviction sesuai kontrak'],
      real_estate_agency: ['Agent mendaftarkan properti dengan foto dan detail lengkap', 'Client booking jadwal untuk melihat properti', 'Agent menunjukkan properti dan menjelaskan kelebihan', 'Buyer mengajukan penawaran harga — agent negosiasi', 'Deal ditutup — komisi agent dibayarkan', 'Validasi: harga listing harus realistis berdasarkan analisa pasar', 'Error message: \"Harga properti di luar estimasi\"', 'Edge case: buyer mundur setelah deal — deal jadi batal dan listing diaktifkan kembali'],
      strata_management: ['Manager menagih iuran bulanan ke semua pemilik unit', 'Pembayaran iuran dicatat dan status diperbarui', 'Perbaikan fasilitas umum dijadwalkan dan dieksekusi', 'Rapat komite diadakan untuk membahas anggaran', 'Laporan keuangan disusun dan dipresentasikan', 'Validasi: iuran harus dibayar sebelum tanggal jatuh tempo', 'Error message: \"Iuran bulan {period} belum dibayar\"', 'Edge case: pemilik unit tidak membayar iuran selama 6 bulan — kirim somasi'],
      sports_club: ['Member mendaftar dan memilih paket membership', 'Coach menjadwalkan sesi latihan rutin', 'Member hadir latihan dan melakukan check-in', 'Kehadiran dan performa dicatat oleh coach', 'Membership diperpanjang secara otomatis atau manual', 'Validasi: member harus memiliki membership aktif untuk ikut sesi', 'Error message: \"Membership tidak aktif. Perpanjang dahulu\"', 'Edge case: sesi latihan penuh — member masuk waiting list'],
      volunteer_platform: ['Organizer mempublikasikan project dengan jadwal shift', 'Volunteer mendaftar untuk shift yang tersedia', 'Volunteer hadir dan melaksanakan tugas', 'Jam kerja diverifikasi oleh organizer', 'Dampak project diukur dan dilaporkan', 'Validasi: volunteer harus register sebelum mengisi shift', 'Error message: \"Shift sudah penuh\"', 'Edge case: volunteer tidak hadir — tandai sebagai no-show dan cari pengganti'],
      alumni_network: ['Alumni mendaftar dengan data akademik dan pekerjaan', 'Alumni dapat mencari dan terhubung dengan alumni lain', 'Event reuni atau networking diadakan secara berkala', 'Lowongan kerja diposting oleh alumni untuk alumni', 'Donasi dikumpulkan untuk kegiatan kampus', 'Validasi: email alumni harus domain institusi atau terverifikasi', 'Error message: \"Email tidak terverifikasi sebagai alumni\"', 'Edge case: alumni ingin hapus akun — soft delete dengan data retention'],
      spa: ['Customer booking layanan spa dengan therapist pilihan', 'Customer tiba dan check-in untuk perawatan', 'Therapist memberikan treatment sesuai paket yang dipilih', 'Customer membayar setelah perawatan selesai', 'Customer memberi rating dan review', 'Validasi: booking minimal 1 jam sebelum jadwal', 'Error message: \"Therapist tidak tersedia di jam tersebut\"', 'Edge case: customer alergi produk tertentu — catat di preferensi customer'],
      tailoring: ['Customer konsultasi desain dengan tailor', 'Tailor mengambil ukuran badan customer', 'Tailor memotong kain dan menjahit sesuai pola', 'Customer fitting dan request adjustment', 'Baju jadi dan diantar ke customer', 'Validasi: semua ukuran harus diisi sebelum mulai produksi', 'Error message: \"Ukuran belum lengkap\"', 'Edge case: customer berubah pikiran setelah pengukuran — charge tambahan untuk perubahan'],
      laundry_delivery: ['Customer order laundry dengan pick-up address', 'Driver menjemput laundry ke alamat customer', 'Staff mencuci, mengeringkan, dan menyetrika', 'Driver mengantar kembali ke alamat customer', 'Customer bayar saat terima paket', 'Validasi: berat minimal 1 kg', 'Error message: \"Berat laundry minimal 1 kg\"', 'Edge case: customer tidak ada di tempat saat delivery — reschedule atau titip tetangga'],
      grocery: ['Manager menambah produk baru dengan barcode dan harga', 'Stok barang diterima dari supplier dan dicatat', 'Kasir menscan barcode dan memproses pembayaran', 'Stok berkurang otomatis setelah penjualan', 'Reorder dilakukan saat stok minimum tercapai', 'Validasi: harga jual harus di atas harga beli', 'Error message: \"Barcode tidak ditemukan\"', 'Edge case: produk kadaluwarsa — mark sebagai expired dan jangan dijual'],
      convenience_store: ['Kasir memulai shift dan membuka kas register', 'Customer belanja dan membayar di kasir', 'Kasir scan produk dan menerima pembayaran', 'Stok diperbarui setelah setiap transaksi', 'Shift ditutup dan total penjualan direkonsiliasi', 'Validasi: nominal bayar tidak boleh kurang dari total', 'Error message: \"Uang tidak mencukupi\"', 'Edge case: customer ingin retur barang — validasi struk asli dan batas waktu'],
      pharmacy_retail: ['Apoteker menerima stok obat dari supplier', 'Customer membeli obat bebas atau dengan resep', 'Resep dari dokter divalidasi oleh apoteker', 'Obat didispense dan kasir memproses pembayaran', 'Stok diperbarui dan reorder jika mendekati minimum', 'Validasi: obat resep hanya bisa dibeli dengan resep asli', 'Error message: \"Resep dokter diperlukan untuk obat ini\"', 'Edge case: stok obat habis — catat permintaan customer dan pesan ke supplier']
'''


# ============================================================
# Perform insertions
# ============================================================

# 1. Insert into DOMAIN_PACKS (before `generic: {`)
insertion_point_1 = '  },\n\n  generic: {'
new_packs_section = new_domains_packs + insertion_point_1
# Find the specific occurrence - after coworking closing
content = content.replace(
  "  genericFeatures: ['Space Management', 'Booking System', 'Member Management', 'Plan & Pricing', 'Check-in/Check-out'],\n  },\n\n  generic: {",
  "  genericFeatures: ['Space Management', 'Booking System', 'Member Management', 'Plan & Pricing', 'Check-in/Check-out'],\n  },\n" + new_domains_packs + "\n  generic: {",
  1
)

# 2. Insert into DOMAIN_KEYWORDS (before `};`)
content = content.replace(
    "  coworking: ['coworking', 'co-working', 'kantor bersama', 'shared office', 'ruang kerja'],\n};",
    "  coworking: ['coworking', 'co-working', 'kantor bersama', 'shared office', 'ruang kerja']," + new_keywords + "\n};",
    1
)

# 3. Insert into domainHints (before `};`)
content = content.replace(
    "      property: ['Owner/Agent dapat mendaftarkan properti dengan tipe, alamat, dan harga', 'Tenant dapat melihat properti dan unit yang tersedia', 'Tenant memilih unit — lease agreement dibuat dengan durasi sewa', 'Tenant bayar sewa bulanan — sistem catat payment dan update status', 'Maintenance request dibuat — owner assign dan track progress', 'Validasi: endDate lease harus setelah startDate', 'Error message: \"Tanggal akhir sewa harus setelah tanggal mulai\"', 'Edge case: tenant telat bayar sewa — sistem kirim reminder otomatis dan hitung denda'],\n    };",
    "      property: ['Owner/Agent dapat mendaftarkan properti dengan tipe, alamat, dan harga', 'Tenant dapat melihat properti dan unit yang tersedia', 'Tenant memilih unit — lease agreement dibuat dengan durasi sewa', 'Tenant bayar sewa bulanan — sistem catat payment dan update status', 'Maintenance request dibuat — owner assign dan track progress', 'Validasi: endDate lease harus setelah startDate', 'Error message: \"Tanggal akhir sewa harus setelah tanggal mulai\"', 'Edge case: tenant telat bayar sewa — sistem kirim reminder otomatis dan hitung denda']," + new_hints + "\n    };",
    1
)

with open(JS_FILE, 'w', encoding='utf-8') as f:
    f.write(content)

print("✅ Insertions complete!")
print(f"File saved: {JS_FILE}")
