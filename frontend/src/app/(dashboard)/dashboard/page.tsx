// src/app/(dashboard)/dashboard/page.tsx
"use client";

import { useState, useEffect } from 'react';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Calendar, Clock, Briefcase, BarChart2, Users } from "lucide-react";
import Image from "next/image";
import Link from "next/link";

// Typ dla danych podsumowania
type DashboardData = {
  currentTasks: {
    id: number;
    name: string;
    project: string;
    dueDate: string;
  }[];
  timeStats: {
    hoursThisWeek: number;
    hoursThisMonth: number;
    overtimeHours: number;
  };
  leaveBalance: {
    availableDays: number;
    usedDays: number;
    pendingDays: number;
  };
  upcomingLeaves: {
    id: number;
    startDate: string;
    endDate: string;
    status: string;
    type: string;
  }[];
  teamMembers: {
    id: number;
    name: string;
    role: string;
    avatarUrl: string | null;
  }[];
};

// Przykładowe dane dla dashboardu (w rzeczywistej aplikacji pochodziłyby z API)
const mockDashboardData: DashboardData = {
  currentTasks: [
    { id: 1, name: "Pomiary geodezyjne", project: "Budowa drogi S7", dueDate: "2025-05-12" },
    { id: 2, name: "Inwentaryzacja powykonawcza", project: "Osiedle Zielone Wzgórze", dueDate: "2025-05-15" },
    { id: 3, name: "Mapy do celów projektowych", project: "Centrum handlowe", dueDate: "2025-05-20" }
  ],
  timeStats: {
    hoursThisWeek: 32,
    hoursThisMonth: 145,
    overtimeHours: 6
  },
  leaveBalance: {
    availableDays: 20,
    usedDays: 5,
    pendingDays: 2
  },
  upcomingLeaves: [
    { id: 1, startDate: "2025-06-10", endDate: "2025-06-15", status: "Approved", type: "Urlop wypoczynkowy" }
  ],
  teamMembers: [
    { id: 1, name: "Jan Kowalski", role: "Geodeta", avatarUrl: null },
    { id: 2, name: "Anna Nowak", role: "Kierownik zespołu", avatarUrl: null },
    { id: 3, name: "Piotr Wiśniewski", role: "Asystent", avatarUrl: null }
  ]
};

export default function DashboardPage() {
  const [data, setData] = useState<DashboardData | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  // Symulacja ładowania danych z API
  useEffect(() => {
    const fetchData = async () => {
      try {
        // W rzeczywistej aplikacji byłoby to wywołanie API
        // const response = await fetch('/api/dashboard');
        // const dashboardData = await response.json();
        
        // Używamy przykładowych danych
        setTimeout(() => {
          setData(mockDashboardData);
          setIsLoading(false);
        }, 500);
      } catch (error) {
        console.error('Błąd podczas pobierania danych:', error);
        setIsLoading(false);
      }
    };

    fetchData();
  }, []);

  // Format daty do wyświetlenia
  const formatDate = (dateString: string) => {
    const options: Intl.DateTimeFormatOptions = { 
      year: 'numeric', 
      month: 'long', 
      day: 'numeric' 
    };
    return new Date(dateString).toLocaleDateString('pl-PL', options);
  };

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-full">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (!data) {
    return (
      <div className="text-center p-6">
        <h2 className="text-xl font-semibold mb-2">Nie udało się załadować danych</h2>
        <p className="text-gray-500 mb-4">Spróbuj odświeżyć stronę lub skontaktuj się z administratorem.</p>
        <Button onClick={() => window.location.reload()}>Odśwież stronę</Button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Panel główny</h1>
        <p className="text-gray-500">{new Date().toLocaleDateString('pl-PL', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
      </div>

      {/* Statystyki czasu pracy */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-gray-500">Godziny w tym tygodniu</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center">
              <Clock className="h-5 w-5 text-blue-500 mr-2" />
              <span className="text-2xl font-bold">{data.timeStats.hoursThisWeek}h</span>
              <span className="text-sm text-gray-500 ml-2">/ 40h</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div 
                className="bg-blue-500 h-2 rounded-full" 
                style={{ width: `${(data.timeStats.hoursThisWeek / 40) * 100}%` }}
              ></div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-gray-500">Godziny w tym miesiącu</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center">
              <Calendar className="h-5 w-5 text-green-500 mr-2" />
              <span className="text-2xl font-bold">{data.timeStats.hoursThisMonth}h</span>
              <span className="text-sm text-gray-500 ml-2">/ 168h</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div 
                className="bg-green-500 h-2 rounded-full" 
                style={{ width: `${(data.timeStats.hoursThisMonth / 168) * 100}%` }}
              ></div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="pb-2">
            <CardTitle className="text-sm font-medium text-gray-500">Nadgodziny</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center">
              <BarChart2 className="h-5 w-5 text-purple-500 mr-2" />
              <span className="text-2xl font-bold">{data.timeStats.overtimeHours}h</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Bieżące zadania i urlopy */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Bieżące zadania */}
        <Card className="col-span-1">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Bieżące zadania</CardTitle>
              <Link href="/harmonogram">
                <Button variant="outline" size="sm">Zobacz wszystkie</Button>
              </Link>
            </div>
            <CardDescription>Zadania przypisane do Ciebie</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              {data.currentTasks.map((task) => (
                <div key={task.id} className="border rounded-lg p-3 hover:bg-gray-50 transition-colors">
                  <div className="flex items-start justify-between">
                    <div>
                      <h3 className="font-medium">{task.name}</h3>
                      <p className="text-sm text-gray-500 flex items-center mt-1">
                        <Briefcase className="h-4 w-4 mr-1" />
                        {task.project}
                      </p>
                    </div>
                    <div className="bg-blue-100 text-blue-800 text-xs font-medium px-2 py-1 rounded">
                      {formatDate(task.dueDate)}
                    </div>
                  </div>
                </div>
              ))}
              
              {data.currentTasks.length === 0 && (
                <div className="text-center py-6 text-gray-500">
                  <p>Brak bieżących zadań</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Informacje o urlopach */}
        <Card className="col-span-1">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>Urlopy</CardTitle>
              <Link href="/urlopy">
                <Button variant="outline" size="sm">Złóż wniosek</Button>
              </Link>
            </div>
            <CardDescription>Saldo dni urlopowych i najbliższe urlopy</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-3 gap-4 mb-6">
              <div className="bg-gray-50 rounded-lg p-3 text-center">
                <p className="text-sm text-gray-500">Dostępne dni</p>
                <p className="text-xl font-bold mt-1">{data.leaveBalance.availableDays}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-3 text-center">
                <p className="text-sm text-gray-500">Wykorzystane</p>
                <p className="text-xl font-bold mt-1">{data.leaveBalance.usedDays}</p>
              </div>
              <div className="bg-gray-50 rounded-lg p-3 text-center">
                <p className="text-sm text-gray-500">Oczekujące</p>
                <p className="text-xl font-bold mt-1">{data.leaveBalance.pendingDays}</p>
              </div>
            </div>

            <h3 className="font-medium mb-2">Nadchodzące urlopy</h3>
            <div className="space-y-3">
              {data.upcomingLeaves.map((leave) => (
                <div key={leave.id} className="border rounded-lg p-3 hover:bg-gray-50 transition-colors">
                  <div className="flex items-start justify-between">
                    <div>
                      <h4 className="font-medium">{leave.type}</h4>
                      <p className="text-sm text-gray-500 mt-1">
                        {formatDate(leave.startDate)} - {formatDate(leave.endDate)}
                      </p>
                    </div>
                    <div className={`text-xs font-medium px-2 py-1 rounded 
                      ${leave.status === 'Approved' ? 'bg-green-100 text-green-800' : 
                      leave.status === 'Rejected' ? 'bg-red-100 text-red-800' : 
                      'bg-yellow-100 text-yellow-800'}`}
                    >
                      {leave.status === 'Approved' ? 'Zatwierdzony' : 
                       leave.status === 'Rejected' ? 'Odrzucony' : 
                       'Oczekujący'}
                    </div>
                  </div>
                </div>
              ))}
              
              {data.upcomingLeaves.length === 0 && (
                <div className="text-center py-6 text-gray-500">
                  <p>Brak nadchodzących urlopów</p>
                </div>
              )}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Członkowie zespołu */}
      <Card>
        <CardHeader>
          <CardTitle>Twój zespół</CardTitle>
          <CardDescription>Członkowie Twojego zespołu projektowego</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            {data.teamMembers.map((member) => (
              <div key={member.id} className="flex items-center space-x-3 border rounded-lg p-3">
                <div className="flex-shrink-0 h-10 w-10 bg-gray-200 rounded-full flex items-center justify-center">
                {member.avatarUrl ? (
                    <Image 
                        src={member.avatarUrl} 
                        alt={member.name} 
                        width={40} 
                        height={40} 
                        className="rounded-full" 
                    />
                    ) : (
                    <span className="text-lg font-medium">{member.name.charAt(0)}</span>
                    )}
                </div>
                <div>
                  <p className="font-medium">{member.name}</p>
                  <p className="text-sm text-gray-500">{member.role}</p>
                </div>
              </div>
            ))}
          </div>
        </CardContent>
        <CardFooter className="border-t pt-4">
          <Link href="/kierownik/zespoly">
            <Button variant="outline" className="w-full sm:w-auto">
              <Users className="mr-2 h-4 w-4" />
              Zarządzaj zespołem
            </Button>
          </Link>
        </CardFooter>
      </Card>
    </div>
  );
}