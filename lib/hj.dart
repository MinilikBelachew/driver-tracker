// import { prisma } from '@utils/prisma';
// import { haversineDistance, Location } from '@utils/helpers';
// import { hungarian } from '@utils/hungarian';
// import { driverService } from './driver.js';
// import { passengerService } from './passengers.js';

// // Import types from Prisma client
// import type { Driver, Passenger, Assignment, Trip } from '@prisma/client';
// import { DriverStatus, PassengerStatus, AssignmentStatus, TripStatus } from '@prisma/client';

// interface AssignmentCandidate {
//   driverId: string;
//   passengerId: string;
//   distance: number;
//   estimatedPickupTime: Date;
//   estimatedDropoffTime: Date;
//   canMeetDeadline: boolean;
//   score: number;
// }

// interface DriverState {
//   id: string;
//   currentLocation: Location;
//   status: DriverStatus;
//   capacity: number;
//   currentPassengers: number;
//   lastDropoffTime?: Date;
//   availabilityEnd: Date;
// }

// interface PassengerState {
//   id: string;
//   pickupLocation: Location;
//   dropoffLocation: Location;
//   earliestPickupTime: Date;
//   latestPickupTime: Date;
//   groupSize: number;
//   status: PassengerStatus;
// }

// export class AssignmentService {
//   private readonly MAX_IDLE_TIME_MINUTES = 30;
//   private readonly AVERAGE_SPEED_KMH = 30; // Average speed for time calculations

//   /**
//    * Main assignment cycle that runs global optimization with chaining
//    */
//   async runAssignmentCycle(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Starting assignment cycle...');
      
//       let totalAssignments = 0;
//       let iteration = 1;
//       const maxIterations = 10; // Prevent infinite loops
      
//       while (iteration <= maxIterations) {
//         console.log(`[ASSIGNMENT] Starting iteration ${iteration}...`);
        
//         // Get all drivers (not just available ones) for chaining
//         const drivers = await prisma.driver.findMany({
//           where: {
//             status: {
//               in: ['IDLE', 'WAITING_POST_DROPOFF']
//             }
//           },
//           include: {
//             assignments: {
//               where: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               },
//               orderBy: {
//                 createdAt: 'desc'
//               },
//               take: 1 // Get the most recent assignment for location calculation
//             }
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers`);

//         // Get passengers without assignments
//         const unassignedPassengers = await prisma.passenger.findMany({
//           where: {
//             assignments: {
//               none: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               }
//             },
//             earliestPickupTime: {
//               gt: new Date()
//             }
//           },
//           orderBy: {
//             earliestPickupTime: 'asc'
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${unassignedPassengers.length} passengers with future pickup times`);
        
//         // Log some passenger details for debugging
//         unassignedPassengers.slice(0, 3).forEach(passenger => {
//           console.log(`[ASSIGNMENT] Passenger ${passenger.id}: earliest=${passenger.earliestPickupTime}, latest=${passenger.latestPickupTime}`);
//         });

//         if (drivers.length === 0 || unassignedPassengers.length === 0) {
//           console.log(`[ASSIGNMENT] No available drivers or passengers for assignment. Drivers: ${drivers.length}, Passengers: ${unassignedPassengers.length}`);
//           break;
//         }

//         console.log(`[ASSIGNMENT] Found ${drivers.length} drivers and ${unassignedPassengers.length} unassigned passengers`);

//         // Generate assignment candidates
//         const candidates: AssignmentCandidate[] = [];
        
//         for (const driver of drivers) {
//           // Get driver's current location (either from profile or last dropoff)
//           let driverLat = driver.currentLat;
//           let driverLng = driver.currentLng;
//           let driverCurrentTime = new Date();
          
//           // If driver has recent assignments, use the last dropoff location and time
//           if (driver.assignments.length > 0) {
//             const lastAssignment = driver.assignments[0];
//             const lastPassenger = await prisma.passenger.findUnique({
//               where: { id: lastAssignment.passengerId }
//             });
            
//             if (lastPassenger) {
//               driverLat = lastPassenger.dropoffLat;
//               driverLng = lastPassenger.dropoffLng;
//               // Estimate current time based on last dropoff
//               driverCurrentTime = new Date(lastAssignment.createdAt.getTime() + 30 * 60 * 1000); // 30 min after assignment
//             }
//           }

//           for (const passenger of unassignedPassengers) {
//             // Skip if passenger has no pickup time constraints
//             if (!passenger.earliestPickupTime || !passenger.latestPickupTime) {
//               continue;
//             }
            
//             // Calculate distance and time
//             const distance = haversineDistance(
//               { lat: driverLat, lng: driverLng },
//               { lat: passenger.pickupLat, lng: passenger.pickupLng }
//             );
            
//             const timeToPickup = (distance / this.AVERAGE_SPEED_KMH) * 60; // 30 km/h average speed
//             const estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
            
//             // Check time constraints (relaxed for chaining)
//             const canMeetDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//             const isNotTooEarly = estimatedPickupTime >= new Date(passenger.earliestPickupTime.getTime() - 2 * 60 * 60 * 1000); // Within 2 hours before earliest
            
//             if (canMeetDeadline && isNotTooEarly) {
//               // Calculate score
//               let score = 1000 - distance; // Base score (lower distance = higher score)
              
//               // Bonus for chaining (if driver already has assignments)
//               if (driver.assignments.length > 0) {
//                 score += 100; // Bonus for chaining
//               }
              
//               // Penalty for idle time (if driver has been idle)
//               const idleTime = Date.now() - driverCurrentTime.getTime();
//               if (idleTime > this.MAX_IDLE_TIME_MINUTES * 60 * 1000) { // 30 minutes
//                 score -= (idleTime - this.MAX_IDLE_TIME_MINUTES * 60 * 1000) / (60 * 1000); // Penalty per minute of idle time
//               }
              
//               candidates.push({
//                 driverId: driver.id,
//                 passengerId: passenger.id,
//                 score: Math.max(0, score), // Ensure non-negative score
//                 distance,
//                 estimatedPickupTime,
//                 estimatedDropoffTime: new Date(estimatedPickupTime.getTime() + (distance / this.AVERAGE_SPEED_KMH) * 60 * 1000), // Estimate dropoff time
//                 canMeetDeadline: true
//               });
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);

//         if (candidates.length === 0) {
//           console.log('[ASSIGNMENT] No valid assignment candidates found');
//           break;
//         }

//         // Use Hungarian algorithm for optimal assignment
//         const assignments = this.runHungarianAlgorithm(candidates, drivers.length, unassignedPassengers.length);
        
//         console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignments);

//         // Process assignments
//         let assignmentsMade = 0;
//         for (let i = 0; i < Math.min(drivers.length, unassignedPassengers.length); i++) {
//           const assignmentIndex = assignments[i];
//           if (assignmentIndex !== -1 && assignmentIndex < candidates.length) {
//             const candidate = candidates[assignmentIndex];
            
//             console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${assignmentIndex}`);
            
//             const driver = drivers.find(d => d.id === candidate.driverId);
//             const passenger = unassignedPassengers.find(p => p.id === candidate.passengerId);
            
//             if (driver && passenger) {
//               console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
//               console.log(`[ASSIGNMENT] Found candidate for assignment`);
              
//               // Create assignment
//               await prisma.assignment.create({
//                 data: {
//                   driverId: driver.id,
//                   passengerId: passenger.id,
//                   status: 'PENDING',
//                   assignedAt: new Date(),
//                   estimatedPickupTime: candidate.estimatedPickupTime,
//                   estimatedDropoffTime: candidate.estimatedDropoffTime
//                 }
//               });
              
//               console.log(`[ASSIGNMENT] Created assignment: Driver ${driver.id} -> Passenger ${passenger.id}`);
//               assignmentsMade++;
//               totalAssignments++;
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Iteration ${iteration} completed. ${assignmentsMade} assignments made.`);
        
//         if (assignmentsMade === 0) {
//           console.log('[ASSIGNMENT] No assignments made in this iteration, stopping');
//           break;
//         }

//         // Simulate dropoffs for next iteration
//         console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignmentsMade} assignments...`);
//         const recentAssignments = await prisma.assignment.findMany({
//           where: {
//             status: 'ASSIGNED',
//             assignedAt: {
//               gte: new Date(Date.now() - 60 * 1000) // Last minute
//             }
//           },
//           include: {
//             passenger: true
//           }
//         });

//         for (const assignment of recentAssignments) {
//           // Update driver location to dropoff point
//           await prisma.driver.update({
//             where: { id: assignment.driverId },
//             data: {
//               currentLat: assignment.passenger.dropoffLatitude,
//               currentLng: assignment.passenger.dropoffLongitude,
//               lastDropoffLat: assignment.passenger.dropoffLatitude,
//               lastDropoffLng: assignment.passenger.dropoffLongitude,
//               lastDropoffTimestamp: assignment.estimatedPickupTime, // Use estimatedPickupTime for dropoff
//               status: DriverStatus.WAITING_POST_DROPOFF,
//               updatedAt: new Date()
//             }
//           });
//           console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${assignment.passenger.dropoffLatitude}, ${assignment.passenger.dropoffLongitude})`);
//         }

//         iteration++;
//       }
      
//       console.log(`[ASSIGNMENT] Assignment cycle completed. Total assignments: ${totalAssignments} in ${iteration - 1} iterations.`);
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error in assignment cycle:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get available drivers for assignment
//    */
//   private async getAvailableDrivers(): Promise<DriverState[]> {
//     const drivers = await prisma.driver.findMany({
//       where: {
//         status: {
//           in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//         },
//         availabilityEnd: {
//           gte: new Date()
//         }
//       },
//       include: {
//         assignedPassengers: {
//           where: {
//             status: {
//               in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP]
//             }
//           }
//         }
//       }
//     });

//     // Filter out drivers who are currently assigned to passengers
//     const availableDrivers = drivers.filter((driver: any) => 
//       driver.assignedPassengers?.length === 0
//     );

//     console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers, ${availableDrivers.length} available for assignment`);

//     return availableDrivers.map((driver: any) => ({
//       id: driver.id,
//       currentLocation: this.getDriverCurrentLocation(driver),
//       status: driver.status,
//       capacity: driver.capacity,
//       currentPassengers: 0, // Reset to 0 since we filtered out assigned drivers
//       lastDropoffTime: driver.lastDropoffTimestamp || undefined,
//       availabilityEnd: driver.availabilityEnd
//     }));
//   }

//   /**
//    * Get unassigned passengers
//    */
//   private async getUnassignedPassengers(): Promise<PassengerState[]> {
//     const passengers = await prisma.passenger.findMany({
//       where: {
//         status: PassengerStatus.UNASSIGNED,
//         latestPickupTime: {
//           gte: new Date()
//         }
//       }
//     });

//     console.log(`[ASSIGNMENT] Found ${passengers.length} passengers with future pickup times`);
    
//     // Log first few passengers to understand the time data
//     for (let i = 0; i < Math.min(3, passengers.length); i++) {
//       const p = passengers[i];
//       console.log(`[ASSIGNMENT] Passenger ${p.id}: earliest=${p.earliestPickupTime?.toISOString()}, latest=${p.latestPickupTime?.toISOString()}`);
//     }

//     return passengers.map((passenger: any) => ({
//       id: passenger.id,
//       pickupLocation: { lat: passenger.pickupLat, lng: passenger.pickupLng },
//       dropoffLocation: { lat: passenger.dropoffLat, lng: passenger.dropoffLng },
//       earliestPickupTime: passenger.earliestPickupTime || new Date(),
//       latestPickupTime: passenger.latestPickupTime || new Date(Date.now() + 24 * 60 * 60 * 1000), // Default to 24 hours from now
//       groupSize: passenger.groupSize,
//       status: passenger.status
//     }));
//   }

//   /**
//    * Get driver's current location (prioritizing last dropoff location)
//    */
//   private getDriverCurrentLocation(driver: any): Location {
//     // Priority: last dropoff location > current location
//     if (driver.lastDropoffLat && driver.lastDropoffLng) {
//       return { lat: driver.lastDropoffLat, lng: driver.lastDropoffLng };
//     }
//     return { lat: driver.currentLat, lng: driver.currentLng };
//   }

//   /**
//    * Generate all possible assignment candidates with scoring
//    */
//   private async generateAssignmentCandidates(
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     const candidates: AssignmentCandidate[] = [];
//     const now = new Date();

//     for (const driver of drivers) {
//       for (const passenger of passengers) {
//         // Check capacity constraint
//         if (driver.currentPassengers + passenger.groupSize > driver.capacity) {
//           continue;
//         }

//         // Calculate distance and times
//         const distanceToPickup = haversineDistance(driver.currentLocation, passenger.pickupLocation);
//         const distanceToDropoff = haversineDistance(passenger.pickupLocation, passenger.dropoffLocation);
        
//         // Estimate travel times (in minutes)
//         const timeToPickup = (distanceToPickup / this.AVERAGE_SPEED_KMH) * 60;
//         const timeToDropoff = (distanceToDropoff / this.AVERAGE_SPEED_KMH) * 60;
        
//         // Calculate estimated times based on driver's current time
//         const driverCurrentTime = driver.lastDropoffTime || now;
//         const estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//         const estimatedDropoffTime = new Date(estimatedPickupTime.getTime() + timeToDropoff * 60 * 1000);
        
//         // Check if driver can meet the time constraints
//         const canMeetLatestDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//         const canMeetEarliestDeadline = estimatedPickupTime >= passenger.earliestPickupTime;
        
//         // TEMPORARY: Disable time constraints for testing
//         const canMeetDeadline = true; // Allow all assignments for now
        
//         // Debug: Log first few attempts to understand the issue
//         if (candidates.length < 3) {
//           console.log(`[ASSIGNMENT] Debug - Driver ${driver.id} -> Passenger ${passenger.id}:`);
//           console.log(`  Distance: ${distanceToPickup.toFixed(2)}km, Time to pickup: ${timeToPickup.toFixed(1)}min`);
//           console.log(`  Current time: ${now.toISOString()}`);
//           console.log(`  Estimated pickup: ${estimatedPickupTime.toISOString()}`);
//           console.log(`  Earliest allowed: ${passenger.earliestPickupTime.toISOString()}`);
//           console.log(`  Latest allowed: ${passenger.latestPickupTime.toISOString()}`);
//           console.log(`  Can meet deadline: ${canMeetDeadline}`);
//         }
        
//         if (!canMeetDeadline) {
//           continue; // Skip if driver cannot meet the deadline
//         }

//         // Calculate assignment score (lower is better for Hungarian algorithm)
//         const score = this.calculateAssignmentScore({
//           driver,
//           passenger,
//           distanceToPickup,
//           distanceToDropoff,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline
//         });

//         candidates.push({
//           driverId: driver.id,
//           passengerId: passenger.id,
//           distance: distanceToPickup,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline,
//           score
//         });
//       }
//     }

//     console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);
//     return candidates;
//   }

//   /**
//    * Calculate assignment score (lower is better for optimization)
//    */
//   private calculateAssignmentScore(params: {
//     driver: DriverState;
//     passenger: PassengerState;
//     distanceToPickup: number;
//     distanceToDropoff: number;
//     estimatedPickupTime: Date;
//     estimatedDropoffTime: Date;
//     canMeetDeadline: boolean;
//   }): number {
//     const { driver, passenger, distanceToPickup, estimatedPickupTime } = params;
    
//     let score = distanceToPickup * 10; // Base score from distance
    
//     // Time constraint scoring
//     const timeToLatest = passenger.latestPickupTime.getTime() - estimatedPickupTime.getTime();
//     const timeToEarliest = estimatedPickupTime.getTime() - passenger.earliestPickupTime.getTime();
//     const timeToLatestMinutes = timeToLatest / (1000 * 60);
//     const timeToEarliestMinutes = timeToEarliest / (1000 * 60);
    
//     // Penalty for being close to latest pickup time
//     if (timeToLatestMinutes < 15) {
//       score += (15 - timeToLatestMinutes) * 10; // Higher penalty for tight timing
//     }
    
//     // Bonus for optimal timing (not too early, not too late)
//     if (timeToEarliestMinutes >= 0 && timeToEarliestMinutes <= 30) {
//       score -= Math.min(timeToEarliestMinutes * 0.3, 5); // Bonus for good timing
//     }
    
//     // Penalty for being too early
//     if (timeToEarliestMinutes < 0) {
//       score += Math.abs(timeToEarliestMinutes) * 2; // Penalty for being too early
//     }
    
//     // Bonus for drivers who just dropped off (encourage chaining)
//     if (driver.status === DriverStatus.WAITING_POST_DROPOFF) {
//       const idleTime = driver.lastDropoffTime ? 
//         (Date.now() - driver.lastDropoffTime.getTime()) / (1000 * 60) : 0;
      
//       if (idleTime < 5) {
//         score -= 20; // Big bonus for immediate chaining
//       } else if (idleTime < 15) {
//         score -= 10; // Medium bonus for quick chaining
//       } else if (idleTime > this.MAX_IDLE_TIME_MINUTES) {
//         score += (idleTime - this.MAX_IDLE_TIME_MINUTES) * 3; // Higher penalty for excessive idle time
//       }
//     }
    
//     return Math.max(0, score); // Ensure non-negative score
//   }

//   /**
//    * Run global optimization using Hungarian algorithm
//    */
//   private async runGlobalOptimization(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     if (candidates.length === 0) return [];

//     // Create cost matrix for Hungarian algorithm
//     const costMatrix = this.createCostMatrix(candidates, drivers, passengers);
    
//     // Run Hungarian algorithm
//     const assignment = hungarian(costMatrix);
    
//     // Convert assignment result back to candidates
//     const optimalAssignments: AssignmentCandidate[] = [];
//     console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignment);
//     console.log(`[ASSIGNMENT] Drivers length: ${drivers.length}, Passengers length: ${passengers.length}`);
    
//     for (let i = 0; i < assignment.length && i < drivers.length; i++) {
//       const passengerIndex = assignment[i];
//       console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${passengerIndex}`);
      
//       if (passengerIndex < passengers.length) {
//         const driver = drivers[i];
//         const passenger = passengers[passengerIndex];
        
//         // Safety check to ensure both driver and passenger exist
//         if (driver && passenger) {
//           console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
          
//           // Find the corresponding candidate
//           const candidate = candidates.find(c => 
//             c.driverId === driver.id && c.passengerId === passenger.id
//           );
          
//           if (candidate) {
//             console.log(`[ASSIGNMENT] Found candidate for assignment`);
//             optimalAssignments.push(candidate);
//           } else {
//             console.log(`[ASSIGNMENT] No candidate found for driver ${driver.id} and passenger ${passenger.id}`);
//           }
//         } else {
//           console.log(`[ASSIGNMENT] Missing driver or passenger: driver=${!!driver}, passenger=${!!passenger}`);
//         }
//       } else {
//         console.log(`[ASSIGNMENT] Passenger index ${passengerIndex} out of range (max: ${passengers.length})`);
//       }
//     }

//     return optimalAssignments;
//   }

//   /**
//    * Create cost matrix for Hungarian algorithm
//    */
//   private createCostMatrix(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): number[][] {
//     const matrix: number[][] = [];
    
//     // Create a square matrix (pad with dummy assignments if needed)
//     const maxSize = Math.max(drivers.length, passengers.length);
    
//     for (let i = 0; i < maxSize; i++) {
//       matrix[i] = [];
//       for (let j = 0; j < maxSize; j++) {
//         if (i < drivers.length && j < passengers.length) {
//           // Find candidate for this driver-passenger pair
//           const candidate = candidates.find(c => 
//             c.driverId === drivers[i].id && c.passengerId === passengers[j].id
//           );
//           matrix[i][j] = candidate ? candidate.score : 999999; // High cost for invalid assignments
//         } else {
//           matrix[i][j] = 999999; // Dummy assignments with high cost
//         }
//       }
//     }
    
//     return matrix;
//   }

//   /**
//    * Execute the optimal assignments
//    */
//   private async executeAssignments(assignments: AssignmentCandidate[]): Promise<void> {
//     for (const assignment of assignments) {
//       try {
//         await this.createAssignment(assignment);
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Failed to create assignment for driver ${assignment.driverId} and passenger ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Create a single assignment
//    */
//   private async createAssignment(candidate: AssignmentCandidate): Promise<void> {
//     const { driverId, passengerId, estimatedPickupTime, estimatedDropoffTime } = candidate;

//     // Use transaction to ensure data consistency
//     await prisma.$transaction(async (tx: any) => {
//       // 1. Update passenger status
//       await tx.passenger.update({
//         where: { id: passengerId },
//         data: {
//           status: PassengerStatus.ASSIGNED,
//           assignedDriverId: driverId,
//           updatedAt: new Date()
//         }
//       });

//       // 2. Update driver status
//       await tx.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.EN_ROUTE_TO_PICKUP,
//           updatedAt: new Date()
//         }
//       });

//       // 3. Create assignment record
//       await tx.assignment.create({
//         data: {
//           driverId,
//           passengerId,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           status: AssignmentStatus.PENDING,
//           assignedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Created assignment: Driver ${driverId} -> Passenger ${passengerId}`);
//     });
//   }

//   /**
//    * Handle post-dropoff logic - update driver location and status
//    */
//   async handlePostDropoff(driverId: string, dropoffLocation: Location): Promise<void> {
//     try {
//       await prisma.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.WAITING_POST_DROPOFF,
//           lastDropoffTimestamp: new Date(),
//           lastDropoffLat: dropoffLocation.lat,
//           lastDropoffLng: dropoffLocation.lng,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driverId} marked as waiting post-dropoff at ${dropoffLocation.lat}, ${dropoffLocation.lng}`);
//     } catch (error) {
//       console.error(`[ASSIGNMENT] Error handling post-dropoff for driver ${driverId}:`, error);
//       throw error;
//     }
//   }

//   /**
//    * Check and handle idle time expiration
//    */
//   async checkIdleTimeExpiration(): Promise<void> {
//     const thirtyMinutesAgo = new Date(Date.now() - this.MAX_IDLE_TIME_MINUTES * 60 * 1000);
    
//     const idleDrivers = await prisma.driver.findMany({
//       where: {
//         status: DriverStatus.WAITING_POST_DROPOFF,
//         lastDropoffTimestamp: {
//           lt: thirtyMinutesAgo
//         }
//       }
//     });

//     for (const driver of idleDrivers) {
//       await prisma.driver.update({
//         where: { id: driver.id },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driver.id} idle time expired, status reset to IDLE`);
//     }
//   }

//   /**
//    * Simulate dropoffs and update driver locations for chained assignments
//    */
//   private async simulateDropoffsAndUpdateLocations(assignments: AssignmentCandidate[]): Promise<void> {
//     console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignments.length} assignments...`);
    
//     for (const assignment of assignments) {
//       try {
//         // Get the passenger details to get dropoff location
//         const passenger = await prisma.passenger.findUnique({
//           where: { id: assignment.passengerId }
//         });
        
//         if (passenger) {
//           // Update driver location to passenger's dropoff location
//           await prisma.driver.update({
//             where: { id: assignment.driverId },
//             data: {
//               currentLat: passenger.dropoffLat,
//               currentLng: passenger.dropoffLng,
//               lastDropoffLat: passenger.dropoffLat,
//               lastDropoffLng: passenger.dropoffLng,
//               lastDropoffTimestamp: assignment.estimatedDropoffTime,
//               status: DriverStatus.WAITING_POST_DROPOFF,
//               updatedAt: new Date()
//             }
//           });
          
//           console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         }
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Error simulating dropoff for assignment ${assignment.driverId} -> ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Reset assignment system for testing (unassign all passengers and reset drivers)
//    */
//   async resetAssignmentSystem(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Resetting assignment system...');
      
//       // Reset all passengers to unassigned
//       await prisma.passenger.updateMany({
//         where: {
//           status: {
//             in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP, PassengerStatus.DROPPED_OFF]
//           }
//         },
//         data: {
//           status: PassengerStatus.UNASSIGNED,
//           assignedDriverId: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Reset all drivers to idle
//       await prisma.driver.updateMany({
//         where: {
//           status: {
//             in: [DriverStatus.EN_ROUTE_TO_PICKUP, DriverStatus.EN_ROUTE_TO_DROPOFF, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Delete all assignments
//       await prisma.assignment.deleteMany({});
      
//       console.log('[ASSIGNMENT] Assignment system reset completed');
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error resetting assignment system:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get assignment statistics
//    */
//   async getAssignmentStats(): Promise<{
//     totalDrivers: number;
//     availableDrivers: number;
//     totalPassengers: number;
//     unassignedPassengers: number;
//     activeAssignments: number;
//   }> {
//     const [
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     ] = await Promise.all([
//       prisma.driver.count(),
//       prisma.driver.count({
//         where: {
//           status: {
//             in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         }
//       }),
//       prisma.passenger.count(),
//       prisma.passenger.count({
//         where: { status: PassengerStatus.UNASSIGNED }
//       }),
//       prisma.assignment.count({
//         where: {
//           status: {
//             in: [AssignmentStatus.PENDING, AssignmentStatus.CONFIRMED, AssignmentStatus.IN_PROGRESS]
//           }
//         }
//       })
//     ]);

//     return {
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     };
//   }
// }

// export const assignmentService = new AssignmentService();









// import { prisma } from '@utils/prisma';
// import { haversineDistance, Location } from '@utils/helpers';
// import { hungarian } from '@utils/hungarian';
// import { driverService } from './driver.js';
// import { passengerService } from './passengers.js';

// // Import types from Prisma client
// import type { Driver, Passenger, Assignment, Trip } from '@prisma/client';
// import { DriverStatus, PassengerStatus, AssignmentStatus, TripStatus } from '@prisma/client';

// interface AssignmentCandidate {
//   driverId: string;
//   passengerId: string;
//   distance: number;
//   estimatedPickupTime: Date;
//   estimatedDropoffTime: Date;
//   canMeetDeadline: boolean;
//   score: number;
//   waitingTimeMinutes: number;
// }

// interface DriverState {
//   id: string;
//   currentLocation: Location;
//   status: DriverStatus;
//   capacity: number;
//   currentPassengers: number;
//   lastDropoffTime?: Date;
//   availabilityEnd: Date;
//   idleTimeMinutes?: number;
// }

// interface PassengerState {
//   id: string;
//   pickupLocation: Location;
//   dropoffLocation: Location;
//   earliestPickupTime: Date;
//   latestPickupTime: Date;
//   groupSize: number;
//   status: PassengerStatus;
// }

// interface IdleTimeInfo {
//   driverId: string;
//   driverName: string;
//   idleTimeMinutes: number;
//   lastDropoffTime?: Date;
//   currentLocation: Location;
//   status: DriverStatus;
// }

// export class AssignmentService {
//   private readonly MAX_IDLE_TIME_MINUTES = 30;
//   private readonly AVERAGE_SPEED_KMH = 60; // Average speed for time calculations
//   private MAX_WAITING_TIME_MINUTES = 60; // Maximum time driver can wait for passenger
//   private MIN_WAITING_TIME_MINUTES = 0; // Minimum waiting time (can be 0 for no waiting)

//   /**
//    * Main assignment cycle that runs global optimization with chaining
//    */
//   async runAssignmentCycle(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Starting assignment cycle...');
      
//       let totalAssignments = 0;
//       let iteration = 1;
//       const maxIterations = 10; // Prevent infinite loops
      
//       while (iteration <= maxIterations) {
//         console.log(`[ASSIGNMENT] Starting iteration ${iteration}...`);
        
//         // Get all drivers (not just available ones) for chaining
//         const drivers = await prisma.driver.findMany({
//           where: {
//             status: {
//               in: ['IDLE', 'WAITING_POST_DROPOFF']
//             }
//           },
//           include: {
//             assignments: {
//               where: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               },
//               orderBy: {
//                 createdAt: 'desc'
//               },
//               take: 1 // Get the most recent assignment for location calculation
//             }
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers`);

//         // Get passengers without assignments
//         const unassignedPassengers = await prisma.passenger.findMany({
//           where: {
//             assignments: {
//               none: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               }
//             }
//           },
//           orderBy: {
//             earliestPickupTime: 'asc'
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${unassignedPassengers.length} passengers with future pickup times`);
        
//         // Log some passenger details for debugging
//         unassignedPassengers.slice(0, 3).forEach(passenger => {
//           console.log(`[ASSIGNMENT] Passenger ${passenger.id}: earliest=${passenger.earliestPickupTime}, latest=${passenger.latestPickupTime}`);
//         });

//         // Filter passengers based on pickup time - handle both immediate and scheduled pickups
//         const now = new Date();
//         const immediatePassengers = unassignedPassengers.filter(passenger => {
//           if (!passenger.earliestPickupTime || !passenger.latestPickupTime) return false;
          
//           // Immediate pickup: passenger needs pickup within the next 2 hours
//           const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
//           return passenger.latestPickupTime <= twoHoursFromNow;
//         });

//         const scheduledPassengers = unassignedPassengers.filter(passenger => {
//           if (!passenger.earliestPickupTime || !passenger.latestPickupTime) return false;
          
//           // Scheduled pickup: passenger needs pickup more than 2 hours from now
//           const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
//           return passenger.latestPickupTime > twoHoursFromNow;
//         });

//         console.log(`[ASSIGNMENT] Immediate passengers (within 2 hours): ${immediatePassengers.length}`);
//         console.log(`[ASSIGNMENT] Scheduled passengers (future): ${scheduledPassengers.length}`);

//         // For now, focus on scheduled passengers only
//         const passengersToAssign = scheduledPassengers;

//         if (passengersToAssign.length === 0) {
//           console.log(`[ASSIGNMENT] No scheduled passengers to assign.`);
//         }

//         // Generate assignment candidates
//         const candidates: AssignmentCandidate[] = [];
        
//         for (const driver of drivers) {
//           // Get driver's current location (either from profile or last dropoff)
//           let driverLat = driver.currentLat;
//           let driverLng = driver.currentLng;
//           let driverCurrentTime = new Date();
          
//           // If driver has recent assignments, use the last dropoff location and time
//           if (driver.assignments.length > 0) {
//             const lastAssignment = driver.assignments[0];
//             const lastPassenger = await prisma.passenger.findUnique({
//               where: { id: lastAssignment.passengerId }
//             });
            
//             if (lastPassenger) {
//               driverLat = lastPassenger.dropoffLat;
//               driverLng = lastPassenger.dropoffLng;
//               // Estimate current time based on last dropoff
//               driverCurrentTime = new Date(lastAssignment.createdAt.getTime() + 30 * 60 * 1000); // 30 min after assignment
//             }
//           }

//           for (const passenger of passengersToAssign) {
//             // Skip if passenger has no pickup time constraints
//             if (!passenger.earliestPickupTime || !passenger.latestPickupTime) {
//               continue;
//             }
            
//             // Calculate distance and time
//             const distance = haversineDistance(
//               { lat: driverLat, lng: driverLng },
//               { lat: passenger.pickupLat, lng: passenger.pickupLng }
//             );
            
//             const timeToPickup = (distance / this.AVERAGE_SPEED_KMH) * 60; // minutes
//             let estimatedPickupTime: Date;
//             let waitingTimeMinutes = 0;

//             // For scheduled passengers, adjust driver departure so waiting time is between 30 and 60 minutes
//             if (passenger.earliestPickupTime) {
//               const latestAllowedArrival = new Date(passenger.earliestPickupTime.getTime() - 30 * 60 * 1000);
//               const earliestAllowedArrival = new Date(passenger.earliestPickupTime.getTime() - 60 * 60 * 1000);
//               const earliestDeparture = new Date(earliestAllowedArrival.getTime() - timeToPickup * 60 * 1000);
//               const latestDeparture = new Date(latestAllowedArrival.getTime() - timeToPickup * 60 * 1000);

//               if (driverCurrentTime < earliestDeparture) {
//                 estimatedPickupTime = new Date(earliestAllowedArrival.getTime());
//                 waitingTimeMinutes = 60;
//               } else if (driverCurrentTime > latestDeparture) {
//                 estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//                 waitingTimeMinutes = (passenger.earliestPickupTime.getTime() - estimatedPickupTime.getTime()) / (1000 * 60);
//               } else {
//                 estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//                 waitingTimeMinutes = (passenger.earliestPickupTime.getTime() - estimatedPickupTime.getTime()) / (1000 * 60);
//                 if (waitingTimeMinutes < 30) waitingTimeMinutes = 30;
//                 if (waitingTimeMinutes > 60) waitingTimeMinutes = 60;
//               }
//             } else {
//               estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//               waitingTimeMinutes = 0;
//             }
            
//             // Check time constraints
//             const canMeetDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//             const isNotTooEarly = estimatedPickupTime >= new Date(passenger.earliestPickupTime.getTime() - 24 * 60 * 60 * 1000); // Within 24 hours before earliest
//             const waitingTimeAcceptable = waitingTimeMinutes <= this.MAX_WAITING_TIME_MINUTES && waitingTimeMinutes >= this.MIN_WAITING_TIME_MINUTES;
            
//             if (canMeetDeadline && isNotTooEarly && waitingTimeAcceptable) {
//               // Calculate score
//               let score = 1000 - distance; // Base score (lower distance = higher score)
              
//               // Bonus for chaining (if driver already has assignments)
//               if (driver.assignments.length > 0) {
//                 score += 100; // Bonus for chaining
//               }
              
//               // Penalty for waiting time (prefer passengers that don't require waiting)
//               if (waitingTimeMinutes > 0) {
//                 score -= waitingTimeMinutes * 2; // Penalty of 2 points per minute of waiting
//               }
              
//               // Penalty for idle time (if driver has been idle)
//               const idleTime = Date.now() - driverCurrentTime.getTime();
//               if (idleTime > this.MAX_IDLE_TIME_MINUTES * 60 * 1000) { // 30 minutes
//                 score -= (idleTime - this.MAX_IDLE_TIME_MINUTES * 60 * 1000) / (60 * 1000); // Penalty per minute of idle time
//               }
              
//               console.log(`[ASSIGNMENT] Valid candidate: Driver ${driver.id} -> Passenger ${passenger.id}`);
//               console.log(`   Distance: ${distance.toFixed(2)} km, Time to pickup: ${timeToPickup.toFixed(1)} min`);
//               console.log(`   Estimated pickup: ${estimatedPickupTime.toLocaleString()}`);
//               console.log(`   Waiting time: ${waitingTimeMinutes.toFixed(1)} min, Score: ${score.toFixed(1)}`);
              
//               candidates.push({
//                 driverId: driver.id,
//                 passengerId: passenger.id,
//                 score: Math.max(0, score), // Ensure non-negative score
//                 distance,
//                 estimatedPickupTime,
//                 estimatedDropoffTime: new Date(estimatedPickupTime.getTime() + (distance / this.AVERAGE_SPEED_KMH) * 60 * 1000), // Estimate dropoff time
//                 canMeetDeadline: true,
//                 waitingTimeMinutes
//               });
//             } else {
//               // Log why candidate was rejected
//               if (!canMeetDeadline) {
//                 console.log(`[ASSIGNMENT] Rejected: Driver ${driver.id} -> Passenger ${passenger.id} - Driver would arrive AFTER latest pickup time!`);
//                 console.log(`   Estimated pickup: ${estimatedPickupTime.toLocaleString()}, Latest allowed: ${passenger.latestPickupTime.toLocaleString()}`);
//               } else if (!waitingTimeAcceptable) {
//                 console.log(`[ASSIGNMENT] Rejected: Driver ${driver.id} -> Passenger ${passenger.id} - Waiting time not in acceptable range`);
//                 console.log(`   Waiting time: ${waitingTimeMinutes.toFixed(1)} min, Allowed: ${this.MIN_WAITING_TIME_MINUTES}-${this.MAX_WAITING_TIME_MINUTES} min`);
//               } else if (!isNotTooEarly) {
//                 console.log(`[ASSIGNMENT] Rejected: Driver ${driver.id} -> Passenger ${passenger.id} - Driver would arrive too early (more than 24h before earliest pickup)`);
//                 console.log(`   Estimated pickup: ${estimatedPickupTime.toLocaleString()}, Earliest allowed: ${(new Date(passenger.earliestPickupTime.getTime() - 24 * 60 * 60 * 1000)).toLocaleString()}`);
//               }
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);

//         if (candidates.length === 0) {
//           console.log('[ASSIGNMENT] No valid assignment candidates found');
//           break;
//         }

//         // Use Hungarian algorithm for optimal assignment
//         const assignments = this.runHungarianAlgorithm(candidates, drivers.length, passengersToAssign.length);
        
//         console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignments);

//         // Process assignments
//         let assignmentsMade = 0;
//         for (let i = 0; i < Math.min(drivers.length, passengersToAssign.length); i++) {
//           const assignmentIndex = assignments[i];
//           if (assignmentIndex !== -1 && assignmentIndex < candidates.length) {
//             const candidate = candidates[assignmentIndex];
            
//             console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${assignmentIndex}`);
            
//             const driver = drivers.find(d => d.id === candidate.driverId);
//             const passenger = passengersToAssign.find(p => p.id === candidate.passengerId);
            
//             if (driver && passenger) {
//               console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
//               console.log(`[ASSIGNMENT] Found candidate for assignment`);
              
//               // Create assignment and update passenger status
//               await this.createAssignmentWithPassengerUpdate(candidate);
              
//               console.log(`[ASSIGNMENT] Created assignment: Driver ${driver.id} -> Passenger ${passenger.id}`);
//               assignmentsMade++;
//               totalAssignments++;
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Iteration ${iteration} completed. ${assignmentsMade} assignments made.`);
        
//         if (assignmentsMade === 0) {
//           console.log('[ASSIGNMENT] No assignments made in this iteration, stopping');
//           break;
//         }

//         // Simulate dropoffs for next iteration
//         console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignmentsMade} assignments...`);
//         const recentAssignments = await prisma.assignment.findMany({
//           where: {
//             status: AssignmentStatus.PENDING,
//             assignedAt: {
//               gte: new Date(Date.now() - 60 * 1000) // Last minute
//             }
//           }
//         });

//         for (const assignment of recentAssignments) {
//           // Get passenger details to get dropoff location
//           const passenger = await prisma.passenger.findUnique({
//             where: { id: assignment.passengerId }
//           });
          
//           if (passenger) {
//             // Update driver location to dropoff point
//             await prisma.driver.update({
//               where: { id: assignment.driverId },
//               data: {
//                 currentLat: passenger.dropoffLat,
//                 currentLng: passenger.dropoffLng,
//                 lastDropoffLat: passenger.dropoffLat,
//                 lastDropoffLng: passenger.dropoffLng,
//                 lastDropoffTimestamp: assignment.estimatedPickupTime, // Use estimatedPickupTime for dropoff
//                 status: DriverStatus.WAITING_POST_DROPOFF,
//                 updatedAt: new Date()
//               }
//             });
//             console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//           }
//         }

//         iteration++;
//       }
      
//       console.log(`[ASSIGNMENT] Assignment cycle completed. Total assignments: ${totalAssignments} in ${iteration - 1} iterations.`);
      
//       // Log detailed driver assignment information
//       await this.logDriverAssignments();
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error in assignment cycle:', error);
//       throw error;
//     }
//   }

//   /**
//    * Run Hungarian algorithm for optimal assignment
//    */
//   private runHungarianAlgorithm(candidates: AssignmentCandidate[], numDrivers: number, numPassengers: number): number[] {
//     if (candidates.length === 0) return [];

//     // Create cost matrix for Hungarian algorithm
//     const costMatrix: number[][] = [];
    
//     // Create a square matrix (pad with dummy assignments if needed)
//     const maxSize = Math.max(numDrivers, numPassengers);
    
//     // Get unique driver and passenger IDs in order
//     const driverIds = Array.from(new Set(candidates.map(c => c.driverId)));
//     const passengerIds = Array.from(new Set(candidates.map(c => c.passengerId)));

//     for (let i = 0; i < maxSize; i++) {
//       costMatrix[i] = [];
//       for (let j = 0; j < maxSize; j++) {
//         if (i < numDrivers && j < numPassengers) {
//           // Find candidate for this driver-passenger pair
//           const candidate = candidates.find(c => 
//             c.driverId === driverIds[i] && c.passengerId === passengerIds[j]
//           );
//           costMatrix[i][j] = candidate ? candidate.score : 999999; // High cost for invalid assignments
//         } else {
//           costMatrix[i][j] = 999999; // Dummy assignments with high cost
//         }
//       }
//     }
    
//     // Run Hungarian algorithm
//     const assignment = hungarian(costMatrix);
    
//     console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignment);
//     console.log(`[ASSIGNMENT] Drivers length: ${numDrivers}, Passengers length: ${numPassengers}`);
    
//     return assignment;
//   }

//   /**
//    * Get available drivers for assignment
//    */
//   private async getAvailableDrivers(): Promise<DriverState[]> {
//     const drivers = await prisma.driver.findMany({
//       where: {
//         status: {
//           in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//         },
//         availabilityEnd: {
//           gte: new Date()
//         }
//       },
//       include: {
//         assignedPassengers: {
//           where: {
//             status: {
//               in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP]
//             }
//           }
//         }
//       }
//     });

//     // Filter out drivers who are currently assigned to passengers
//     const availableDrivers = drivers.filter((driver: any) => 
//       driver.assignedPassengers?.length === 0
//     );

//     console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers, ${availableDrivers.length} available for assignment`);

//     return availableDrivers.map((driver: any) => ({
//       id: driver.id,
//       currentLocation: this.getDriverCurrentLocation(driver),
//       status: driver.status,
//       capacity: driver.capacity,
//       currentPassengers: 0, // Reset to 0 since we filtered out assigned drivers
//       lastDropoffTime: driver.lastDropoffTimestamp || undefined,
//       availabilityEnd: driver.availabilityEnd
//     }));
//   }

//   /**
//    * Get unassigned passengers
//    */
//   private async getUnassignedPassengers(): Promise<PassengerState[]> {
//     const passengers = await prisma.passenger.findMany({
//       where: {
//         status: PassengerStatus.UNASSIGNED,
//         latestPickupTime: {
//           gte: new Date()
//         }
//       }
//     });

//     console.log(`[ASSIGNMENT] Found ${passengers.length} passengers with future pickup times`);
    
//     // Log first few passengers to understand the time data
//     for (let i = 0; i < Math.min(3, passengers.length); i++) {
//       const p = passengers[i];
//       console.log(`[ASSIGNMENT] Passenger ${p.id}: earliest=${p.earliestPickupTime?.toISOString()}, latest=${p.latestPickupTime?.toISOString()}`);
//     }

//     return passengers.map((passenger: any) => ({
//       id: passenger.id,
//       pickupLocation: { lat: passenger.pickupLat, lng: passenger.pickupLng },
//       dropoffLocation: { lat: passenger.dropoffLat, lng: passenger.dropoffLng },
//       earliestPickupTime: passenger.earliestPickupTime || new Date(),
//       latestPickupTime: passenger.latestPickupTime || new Date(Date.now() + 24 * 60 * 60 * 1000), // Default to 24 hours from now
//       groupSize: passenger.groupSize,
//       status: passenger.status
//     }));
//   }

//   /**
//    * Get driver's current location (prioritizing last dropoff location)
//    */
//   private getDriverCurrentLocation(driver: any): Location {
//     // Priority: last dropoff location > current location
//     if (driver.lastDropoffLat && driver.lastDropoffLng) {
//       return { lat: driver.lastDropoffLat, lng: driver.lastDropoffLng };
//     }
//     return { lat: driver.currentLat, lng: driver.currentLng };
//   }

//   /**
//    * Generate all possible assignment candidates with scoring
//    */
//   private async generateAssignmentCandidates(
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     const candidates: AssignmentCandidate[] = [];
//     const now = new Date();

//     for (const driver of drivers) {
//       for (const passenger of passengers) {
//         // Check capacity constraint
//         if (driver.currentPassengers + passenger.groupSize > driver.capacity) {
//           continue;
//         }

//         // Calculate distance and times
//         const distanceToPickup = haversineDistance(driver.currentLocation, passenger.pickupLocation);
//         const distanceToDropoff = haversineDistance(passenger.pickupLocation, passenger.dropoffLocation);
        
//         // Estimate travel times (in minutes)
//         const timeToPickup = (distanceToPickup / this.AVERAGE_SPEED_KMH) * 60;
//         const timeToDropoff = (distanceToDropoff / this.AVERAGE_SPEED_KMH) * 60;
        
//         // Calculate estimated times based on driver's current time
//         const driverCurrentTime = driver.lastDropoffTime || now;
//         const estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//         const estimatedDropoffTime = new Date(estimatedPickupTime.getTime() + timeToDropoff * 60 * 1000);
        
//         // Check if driver can meet the time constraints
//         const canMeetLatestDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//         const canMeetEarliestDeadline = estimatedPickupTime >= passenger.earliestPickupTime;
        
//         // TEMPORARY: Disable time constraints for testing
//         const canMeetDeadline = true; // Allow all assignments for now
        
//         // Debug: Log first few attempts to understand the issue
//         if (candidates.length < 3) {
//           console.log(`[ASSIGNMENT] Debug - Driver ${driver.id} -> Passenger ${passenger.id}:`);
//           console.log(`  Distance: ${distanceToPickup.toFixed(2)}km, Time to pickup: ${timeToPickup.toFixed(1)}min`);
//           console.log(`  Current time: ${now.toISOString()}`);
//           console.log(`  Estimated pickup: ${estimatedPickupTime.toISOString()}`);
//           console.log(`  Earliest allowed: ${passenger.earliestPickupTime.toISOString()}`);
//           console.log(`  Latest allowed: ${passenger.latestPickupTime.toISOString()}`);
//           console.log(`  Can meet deadline: ${canMeetDeadline}`);
//         }
        
//         if (!canMeetDeadline) {
//           continue; // Skip if driver cannot meet the deadline
//         }

//         // Calculate assignment score (lower is better for Hungarian algorithm)
//         const score = this.calculateAssignmentScore({
//           driver,
//           passenger,
//           distanceToPickup,
//           distanceToDropoff,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline
//         });

//         candidates.push({
//           driverId: driver.id,
//           passengerId: passenger.id,
//           distance: distanceToPickup,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline,
//           score,
//           waitingTimeMinutes: 0 // This method doesn't calculate waiting time, so default to 0
//         });
//       }
//     }

//     console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);
//     return candidates;
//   }

//   /**
//    * Calculate assignment score (lower is better for optimization)
//    */
//   private calculateAssignmentScore(params: {
//     driver: DriverState;
//     passenger: PassengerState;
//     distanceToPickup: number;
//     distanceToDropoff: number;
//     estimatedPickupTime: Date;
//     estimatedDropoffTime: Date;
//     canMeetDeadline: boolean;
//   }): number {
//     const { driver, passenger, distanceToPickup, estimatedPickupTime } = params;
    
//     let score = distanceToPickup * 10; // Base score from distance
    
//     // Time constraint scoring
//     const timeToLatest = passenger.latestPickupTime.getTime() - estimatedPickupTime.getTime();
//     const timeToEarliest = estimatedPickupTime.getTime() - passenger.earliestPickupTime.getTime();
//     const timeToLatestMinutes = timeToLatest / (1000 * 60);
//     const timeToEarliestMinutes = timeToEarliest / (1000 * 60);
    
//     // Penalty for being close to latest pickup time
//     if (timeToLatestMinutes < 15) {
//       score += (15 - timeToLatestMinutes) * 10; // Higher penalty for tight timing
//     }
    
//     // Bonus for optimal timing (not too early, not too late)
//     if (timeToEarliestMinutes >= 0 && timeToEarliestMinutes <= 30) {
//       score -= Math.min(timeToEarliestMinutes * 0.3, 5); // Bonus for good timing
//     }
    
//     // Penalty for being too early
//     if (timeToEarliestMinutes < 0) {
//       score += Math.abs(timeToEarliestMinutes) * 2; // Penalty for being too early
//     }
    
//     // Bonus for drivers who just dropped off (encourage chaining)
//     if (driver.status === DriverStatus.WAITING_POST_DROPOFF) {
//       const idleTime = driver.lastDropoffTime ? 
//         (Date.now() - driver.lastDropoffTime.getTime()) / (1000 * 60) : 0;
      
//       if (idleTime < 5) {
//         score -= 20; // Big bonus for immediate chaining
//       } else if (idleTime < 15) {
//         score -= 10; // Medium bonus for quick chaining
//       } else if (idleTime > this.MAX_IDLE_TIME_MINUTES) {
//         score += (idleTime - this.MAX_IDLE_TIME_MINUTES) * 3; // Higher penalty for excessive idle time
//       }
//     }
    
//     return Math.max(0, score); // Ensure non-negative score
//   }

//   /**
//    * Run global optimization using Hungarian algorithm
//    */
//   private async runGlobalOptimization(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     if (candidates.length === 0) return [];

//     // Create cost matrix for Hungarian algorithm
//     const costMatrix = this.createCostMatrix(candidates, drivers, passengers);
    
//     // Run Hungarian algorithm
//     const assignment = hungarian(costMatrix);
    
//     // Convert assignment result back to candidates
//     const optimalAssignments: AssignmentCandidate[] = [];
//     console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignment);
//     console.log(`[ASSIGNMENT] Drivers length: ${drivers.length}, Passengers length: ${passengers.length}`);
    
//     for (let i = 0; i < assignment.length && i < drivers.length; i++) {
//       const passengerIndex = assignment[i];
//       console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${passengerIndex}`);
      
//       if (passengerIndex < passengers.length) {
//         const driver = drivers[i];
//         const passenger = passengers[passengerIndex];
        
//         // Safety check to ensure both driver and passenger exist
//         if (driver && passenger) {
//           console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
          
//           // Find the corresponding candidate
//           const candidate = candidates.find(c => 
//             c.driverId === driver.id && c.passengerId === passenger.id
//           );
          
//           if (candidate) {
//             console.log(`[ASSIGNMENT] Found candidate for assignment`);
//             optimalAssignments.push(candidate);
//           } else {
//             console.log(`[ASSIGNMENT] No candidate found for driver ${driver.id} and passenger ${passenger.id}`);
//           }
//         } else {
//           console.log(`[ASSIGNMENT] Missing driver or passenger: driver=${!!driver}, passenger=${!!passenger}`);
//         }
//       } else {
//         console.log(`[ASSIGNMENT] Passenger index ${passengerIndex} out of range (max: ${passengers.length})`);
//       }
//     }

//     return optimalAssignments;
//   }

//   /**
//    * Create cost matrix for Hungarian algorithm
//    */
//   private createCostMatrix(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): number[][] {
//     const matrix: number[][] = [];
    
//     // Create a square matrix (pad with dummy assignments if needed)
//     const maxSize = Math.max(drivers.length, passengers.length);
    
//     for (let i = 0; i < maxSize; i++) {
//       matrix[i] = [];
//       for (let j = 0; j < maxSize; j++) {
//         if (i < drivers.length && j < passengers.length) {
//           // Find candidate for this driver-passenger pair
//           const candidate = candidates.find(c => 
//             c.driverId === drivers[i].id && c.passengerId === passengers[j].id
//           );
//           matrix[i][j] = candidate ? candidate.score : 999999; // High cost for invalid assignments
//         } else {
//           matrix[i][j] = 999999; // Dummy assignments with high cost
//         }
//       }
//     }
    
//     return matrix;
//   }

//   /**
//    * Execute the optimal assignments
//    */
//   private async executeAssignments(assignments: AssignmentCandidate[]): Promise<void> {
//     for (const assignment of assignments) {
//       try {
//         await this.createAssignment(assignment);
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Failed to create assignment for driver ${assignment.driverId} and passenger ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Create a single assignment
//    */
//   private async createAssignment(candidate: AssignmentCandidate): Promise<void> {
//     const { driverId, passengerId, estimatedPickupTime, estimatedDropoffTime } = candidate;

//     // Use transaction to ensure data consistency
//     await prisma.$transaction(async (tx: any) => {
//       // 1. Update passenger status
//       await tx.passenger.update({
//         where: { id: passengerId },
//         data: {
//           status: PassengerStatus.ASSIGNED,
//           assignedDriverId: driverId,
//           updatedAt: new Date()
//         }
//       });

//       // 2. Update driver status
//       await tx.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.EN_ROUTE_TO_PICKUP,
//           updatedAt: new Date()
//         }
//       });

//       // 3. Create assignment record
//       await tx.assignment.create({
//         data: {
//           driverId,
//           passengerId,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           status: AssignmentStatus.PENDING,
//           assignedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Created assignment: Driver ${driverId} -> Passenger ${passengerId}`);
//     });
//   }

//   /**
//    * Create assignment and update passenger status
//    */
//   private async createAssignmentWithPassengerUpdate(candidate: AssignmentCandidate): Promise<void> {
//     const { driverId, passengerId, estimatedPickupTime, estimatedDropoffTime } = candidate;

//     // Use transaction to ensure data consistency
//     await prisma.$transaction(async (tx) => {
//       // 1. Update passenger status to ASSIGNED
//       await tx.passenger.update({
//         where: { id: passengerId },
//         data: {
//           status: PassengerStatus.ASSIGNED,
//           assignedDriverId: driverId,
//           updatedAt: new Date()
//         }
//       });

//       // 2. Update driver status
//       await tx.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.EN_ROUTE_TO_PICKUP,
//           updatedAt: new Date()
//         }
//       });

//       // 3. Create assignment record
//       await tx.assignment.create({
//         data: {
//           driverId,
//           passengerId,
//           status: AssignmentStatus.PENDING,
//           assignedAt: new Date(),
//           estimatedPickupTime: candidate.estimatedPickupTime,
//           estimatedDropoffTime: candidate.estimatedDropoffTime
//         }
//       });

//       console.log(`[ASSIGNMENT] Created assignment and updated passenger status: Driver ${driverId} -> Passenger ${passengerId}`);
//     });
//   }

//   /**
//    * Complete an assignment and update passenger status to DROPPED_OFF
//    */


//   /**
//    * Handle post-dropoff logic - update driver location and status
//    */
//   async handlePostDropoff(driverId: string, dropoffLocation: Location): Promise<void> {
//     try {
//       await prisma.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.WAITING_POST_DROPOFF,
//           lastDropoffTimestamp: new Date(),
//           lastDropoffLat: dropoffLocation.lat,
//           lastDropoffLng: dropoffLocation.lng,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driverId} marked as waiting post-dropoff at ${dropoffLocation.lat}, ${dropoffLocation.lng}`);
//     } catch (error) {
//       console.error(`[ASSIGNMENT] Error handling post-dropoff for driver ${driverId}:`, error);
//       throw error;
//     }
//   }

//   /**
//    * Check and handle idle time expiration
//    */
//   async checkIdleTimeExpiration(): Promise<void> {
//     const thirtyMinutesAgo = new Date(Date.now() - this.MAX_IDLE_TIME_MINUTES * 60 * 1000);
    
//     const idleDrivers = await prisma.driver.findMany({
//       where: {
//         status: DriverStatus.WAITING_POST_DROPOFF,
//         lastDropoffTimestamp: {
//           lt: thirtyMinutesAgo
//         }
//       }
//     });

//     for (const driver of idleDrivers) {
//       await prisma.driver.update({
//         where: { id: driver.id },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driver.id} idle time expired, status reset to IDLE`);
//     }
//   }

//   /**
//    * Simulate dropoffs and update driver locations for chained assignments
//    */
//   private async simulateDropoffsAndUpdateLocations(assignments: AssignmentCandidate[]): Promise<void> {
//     console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignments.length} assignments...`);
    
//     for (const assignment of assignments) {
//       try {
//         // Get the passenger details to get dropoff location
//         const passenger = await prisma.passenger.findUnique({
//           where: { id: assignment.passengerId }
//         });
        
//         if (passenger) {
//           // Update driver location to passenger's dropoff location
//           await prisma.driver.update({
//             where: { id: assignment.driverId },
//             data: {
//               currentLat: passenger.dropoffLat,
//               currentLng: passenger.dropoffLng,
//               lastDropoffLat: passenger.dropoffLat,
//               lastDropoffLng: passenger.dropoffLng,
//               lastDropoffTimestamp: assignment.estimatedDropoffTime,
//               status: DriverStatus.WAITING_POST_DROPOFF,
//               updatedAt: new Date()
//             }
//           });
          
//           console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         }
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Error simulating dropoff for assignment ${assignment.driverId} -> ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Reset assignment system for testing (unassign all passengers and reset drivers)
//    */
//   async resetAssignmentSystem(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Resetting assignment system...');
      
//       // Reset all passengers to unassigned
//       await prisma.passenger.updateMany({
//         where: {
//           status: {
//             in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP, PassengerStatus.DROPPED_OFF]
//           }
//         },
//         data: {
//           status: PassengerStatus.UNASSIGNED,
//           assignedDriverId: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Reset all drivers to idle
//       await prisma.driver.updateMany({
//         where: {
//           status: {
//             in: [DriverStatus.EN_ROUTE_TO_PICKUP, DriverStatus.EN_ROUTE_TO_DROPOFF, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Delete all assignments
//       await prisma.assignment.deleteMany({});
      
//       console.log('[ASSIGNMENT] Assignment system reset completed');
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error resetting assignment system:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get assignment statistics
//    */
//   async getAssignmentStats(): Promise<{
//     totalDrivers: number;
//     availableDrivers: number;
//     totalPassengers: number;
//     unassignedPassengers: number;
//     activeAssignments: number;
//   }> {
//     const [
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     ] = await Promise.all([
//       prisma.driver.count(),
//       prisma.driver.count({
//         where: {
//           status: {
//             in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         }
//       }),
//       prisma.passenger.count(),
//       prisma.passenger.count({
//         where: { status: PassengerStatus.UNASSIGNED }
//       }),
//       prisma.assignment.count({
//         where: {
//           status: {
//             in: [AssignmentStatus.PENDING, AssignmentStatus.CONFIRMED, AssignmentStatus.IN_PROGRESS]
//           }
//         }
//       })
//     ]);

//     return {
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     };
//   }

//   /**
//    * Get idle time information for all drivers
//    */
//   async getDriverIdleTimes(): Promise<IdleTimeInfo[]> {
//     try {
//       const drivers = await prisma.driver.findMany({
//         where: {
//           status: {
//             in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         },
//         include: {
//           assignments: {
//             where: {
//               status: AssignmentStatus.COMPLETED
//             },
//             orderBy: {
//               actualDropoffTime: 'desc'
//             },
//             take: 1
//           }
//         }
//       });

//       const now = new Date();
//       const idleTimeInfo: IdleTimeInfo[] = [];

//       for (const driver of drivers) {
//         let idleTimeMinutes = 0;
//         let lastDropoffTime: Date | undefined;

//         if (driver.status === DriverStatus.WAITING_POST_DROPOFF && driver.lastDropoffTimestamp) {
//           // Driver is in post-dropoff waiting period
//           lastDropoffTime = driver.lastDropoffTimestamp;
//           idleTimeMinutes = Math.floor((now.getTime() - driver.lastDropoffTimestamp.getTime()) / (1000 * 60));
//         } else if (driver.status === DriverStatus.IDLE) {
//           // Driver is idle - check last completed assignment
//           if (driver.assignments.length > 0) {
//             const lastAssignment = driver.assignments[0];
//             if (lastAssignment.actualDropoffTime) {
//               lastDropoffTime = lastAssignment.actualDropoffTime;
//               idleTimeMinutes = Math.floor((now.getTime() - lastAssignment.actualDropoffTime.getTime()) / (1000 * 60));
//             }
//           }
//         }

//         idleTimeInfo.push({
//           driverId: driver.id,
//           driverName: driver.name,
//           idleTimeMinutes,
//           lastDropoffTime,
//           currentLocation: {
//             lat: driver.currentLat,
//             lng: driver.currentLng
//           },
//           status: driver.status
//         });
//       }

//       // Sort by idle time (longest first)
//       return idleTimeInfo.sort((a, b) => b.idleTimeMinutes - a.idleTimeMinutes);
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error getting driver idle times:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get detailed idle time report
//    */
//   async getIdleTimeReport(): Promise<{
//     totalDrivers: number;
//     idleDrivers: number;
//     waitingPostDropoff: number;
//     averageIdleTime: number;
//     maxIdleTime: number;
//     driversByIdleTime: IdleTimeInfo[];
//   }> {
//     const idleTimeInfo = await this.getDriverIdleTimes();
    
//     const totalDrivers = idleTimeInfo.length;
//     const idleDrivers = idleTimeInfo.filter(d => d.status === DriverStatus.IDLE).length;
//     const waitingPostDropoff = idleTimeInfo.filter(d => d.status === DriverStatus.WAITING_POST_DROPOFF).length;
    
//     const totalIdleTime = idleTimeInfo.reduce((sum, driver) => sum + driver.idleTimeMinutes, 0);
//     const averageIdleTime = totalDrivers > 0 ? Math.round(totalIdleTime / totalDrivers) : 0;
//     const maxIdleTime = Math.max(...idleTimeInfo.map(d => d.idleTimeMinutes), 0);

//     return {
//       totalDrivers,
//       idleDrivers,
//       waitingPostDropoff,
//       averageIdleTime,
//       maxIdleTime,
//       driversByIdleTime: idleTimeInfo
//     };
//   }

//   /**
//    * Log detailed driver assignment information with timing and distance
//    */
//   /**
//    * Get current waiting time constraints
//    */
//   public getWaitingTimeConstraints(): {
//     maxWaitingTimeMinutes: number;
//     minWaitingTimeMinutes: number;
//     averageSpeedKmh: number;
//   } {
//     return {
//       maxWaitingTimeMinutes: this.MAX_WAITING_TIME_MINUTES,
//       minWaitingTimeMinutes: this.MIN_WAITING_TIME_MINUTES,
//       averageSpeedKmh: this.AVERAGE_SPEED_KMH
//     };
//   }

//   /**
//    * Update waiting time constraints
//    */
//   public updateWaitingTimeConstraints(maxWaitingMinutes: number, minWaitingMinutes: number = 0): void {
//     this.MAX_WAITING_TIME_MINUTES = maxWaitingMinutes;
//     this.MIN_WAITING_TIME_MINUTES = minWaitingMinutes;
//     console.log(`[ASSIGNMENT] Updated waiting time constraints: Max=${maxWaitingMinutes}min, Min=${minWaitingMinutes}min`);
//   }

//   public async logDriverAssignments(): Promise<void> {
//     console.log('\n' + '='.repeat(80));
//     console.log('🚗 DRIVER ASSIGNMENT DETAILED REPORT');
//     console.log('='.repeat(80));

//     // Get all drivers with their assignments
//     const drivers = await prisma.driver.findMany({
//       include: {
//         assignments: {
//           where: {
//             status: {
//               in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//             }
//           },
//           include: {
//             passenger: true
//           },
//           orderBy: {
//             assignedAt: 'asc'
//           }
//         }
//       },
//       orderBy: {
//         name: 'asc'
//       }
//     });

//     for (const driver of drivers) {
//       console.log(`\n📋 DRIVER: ${driver.name} (${driver.id})`);
//       console.log(`📍 Current Location: (${driver.currentLat}, ${driver.currentLng})`);
//       console.log(`🕒 Status: ${driver.status}`);
      
//       if (driver.lastDropoffTimestamp) {
//         const idleTime = Math.floor((Date.now() - driver.lastDropoffTimestamp.getTime()) / (1000 * 60));
//         console.log(`⏰ Last Dropoff: ${driver.lastDropoffTimestamp.toLocaleString()}`);
//         console.log(`😴 Idle Time: ${idleTime} minutes`);
//       }

//       if (driver.assignments.length === 0) {
//         console.log(`❌ No assignments`);
//         continue;
//       }

//       console.log(`\n📦 ASSIGNMENTS (${driver.assignments.length}):`);
//       console.log('-'.repeat(80));

//       let currentTime = new Date();
//       let currentLocation = { lat: driver.currentLat, lng: driver.currentLng };
//       let totalWaitingTime = 0;

//       for (let i = 0; i < driver.assignments.length; i++) {
//         const assignment = driver.assignments[i];
//         const passenger = assignment.passenger;

//         console.log(`\n${i + 1}. Passenger: ${passenger.name} (${passenger.id})`);
//         console.log(`   📍 Pickup: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`   🎯 Dropoff: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         console.log(`   ⏰ Earliest Pickup: ${passenger.earliestPickupTime?.toLocaleString() || 'Not set'}`);
//         console.log(`   ⏰ Latest Pickup: ${passenger.latestPickupTime?.toLocaleString() || 'Not set'}`);

//         // Calculate distance from current location to pickup
//         const distanceToPickup = haversineDistance(
//           currentLocation,
//           { lat: passenger.pickupLat, lng: passenger.pickupLng }
//         );

//         // Calculate time to pickup
//         const timeToPickupMinutes = (distanceToPickup / this.AVERAGE_SPEED_KMH) * 60;
//         const estimatedPickupTime = new Date(currentTime.getTime() + timeToPickupMinutes * 60 * 1000);

//         // Calculate distance from pickup to dropoff
//         const distancePickupToDropoff = haversineDistance(
//           { lat: passenger.pickupLat, lng: passenger.pickupLng },
//           { lat: passenger.dropoffLat, lng: passenger.dropoffLng }
//         );

//         // Calculate time from pickup to dropoff
//         const timePickupToDropoffMinutes = (distancePickupToDropoff / this.AVERAGE_SPEED_KMH) * 60;
//         const estimatedDropoffTime = new Date(estimatedPickupTime.getTime() + timePickupToDropoffMinutes * 60 * 1000);

//         // Calculate waiting time if driver arrives early
//         let waitingTimeMinutes = 0;
//         let actualPickupTime = estimatedPickupTime;
//         if (passenger.earliestPickupTime && estimatedPickupTime < passenger.earliestPickupTime) {
//           waitingTimeMinutes = (passenger.earliestPickupTime.getTime() - estimatedPickupTime.getTime()) / (1000 * 60);
//           actualPickupTime = passenger.earliestPickupTime;
//           totalWaitingTime += waitingTimeMinutes;
//         }

//         // Update dropoff time if there was waiting
//         const actualDropoffTime = new Date(actualPickupTime.getTime() + timePickupToDropoffMinutes * 60 * 1000);

//         console.log(`\n   🚗 STEP 1: DRIVER TO PICKUP`);
//         console.log(`      📍 From: (${currentLocation.lat.toFixed(4)}, ${currentLocation.lng.toFixed(4)})`);
//         console.log(`      📍 To: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`      🚗 Distance: ${distanceToPickup.toFixed(2)} km`);
//         console.log(`      ⏱️  Travel Time: ${timeToPickupMinutes.toFixed(1)} minutes`);
//         console.log(`      🕐 Departure: ${currentTime.toLocaleString()}`);
//         console.log(`      🕐 Arrival: ${estimatedPickupTime.toLocaleString()}`);

//         if (waitingTimeMinutes > 0) {
//           console.log(`\n   ⏳ WAITING FOR PASSENGER: ${passenger.name}`);
//           console.log(`      ⏰ Wait Time: ${waitingTimeMinutes.toFixed(1)} minutes`);
//           console.log(`      🕐 Wait From: ${estimatedPickupTime.toLocaleString()}`);
//           console.log(`      🕐 Wait Until: ${actualPickupTime.toLocaleString()}`);
//           console.log(`      📍 Waiting Location: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//           console.log(`      🚗 Driver Status: Waiting at pickup location`);
//         } else {
//           console.log(`\n   ✅ NO WAITING NEEDED`);
//           console.log(`      🕐 Driver arrives at: ${estimatedPickupTime.toLocaleString()}`);
//           console.log(`      ⏰ Passenger ready at: ${passenger.earliestPickupTime?.toLocaleString() || 'No time constraint'}`);
//         }

//         console.log(`\n   🚗 STEP 2: PICKUP TO DROPOFF`);
//         console.log(`      📍 From: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`      📍 To: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         console.log(`      🚗 Distance: ${distancePickupToDropoff.toFixed(2)} km`);
//         console.log(`      ⏱️  Travel Time: ${timePickupToDropoffMinutes.toFixed(1)} minutes`);
//         console.log(`      🕐 Departure: ${actualPickupTime.toLocaleString()}`);
//         console.log(`      🕐 Arrival: ${actualDropoffTime.toLocaleString()}`);

//         // Calculate chaining to next passenger (if not the last assignment)
//         if (i < driver.assignments.length - 1) {
//           const nextAssignment = driver.assignments[i + 1];
//           const nextPassenger = nextAssignment.passenger;
          
//           // Time from current dropoff to next pickup
//           const distanceToNextPickup = haversineDistance(
//             { lat: passenger.dropoffLat, lng: passenger.dropoffLng },
//             { lat: nextPassenger.pickupLat, lng: nextPassenger.pickupLng }
//           );
          
//           const timeToNextPickupMinutes = (distanceToNextPickup / this.AVERAGE_SPEED_KMH) * 60;
//           const nextPickupTime = new Date(actualDropoffTime.getTime() + timeToNextPickupMinutes * 60 * 1000);
          
//           console.log(`\n   🔗 STEP 3: CHAINING TO NEXT PASSENGER`);
//           console.log(`      📍 From: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//           console.log(`      📍 To: (${nextPassenger.pickupLat}, ${nextPassenger.pickupLng})`);
//           console.log(`      🚗 Distance: ${distanceToNextPickup.toFixed(2)} km`);
//           console.log(`      ⏱️  Travel Time: ${timeToNextPickupMinutes.toFixed(1)} minutes`);
//           console.log(`      🕐 Departure: ${actualDropoffTime.toLocaleString()}`);
//           console.log(`      🕐 Arrival: ${nextPickupTime.toLocaleString()}`);
//         }

//         // Update current time and location for next iteration
//         currentTime = actualDropoffTime;
//         currentLocation = { lat: passenger.dropoffLat, lng: passenger.dropoffLng };
//       }

//       // Calculate total trip statistics
//       const totalDistance = driver.assignments.reduce((total, assignment, index) => {
//         const passenger = assignment.passenger;
//         let distance = 0;
        
//         if (index === 0) {
//           // First assignment: distance from current location to pickup
//           distance += haversineDistance(
//             { lat: driver.currentLat, lng: driver.currentLng },
//             { lat: passenger.pickupLat, lng: passenger.pickupLng }
//           );
//         } else {
//           // Distance from previous dropoff to current pickup
//           const prevPassenger = driver.assignments[index - 1].passenger;
//           distance += haversineDistance(
//             { lat: prevPassenger.dropoffLat, lng: prevPassenger.dropoffLng },
//             { lat: passenger.pickupLat, lng: passenger.pickupLng }
//           );
//         }
        
//         // Distance from pickup to dropoff
//         distance += haversineDistance(
//           { lat: passenger.pickupLat, lng: passenger.pickupLng },
//           { lat: passenger.dropoffLat, lng: passenger.dropoffLng }
//         );
        
//         return total + distance;
//       }, 0);

//       const totalTravelTimeMinutes = (totalDistance / this.AVERAGE_SPEED_KMH) * 60;
//       const totalTimeMinutes = totalTravelTimeMinutes + totalWaitingTime;
      
//       console.log(`\n📊 TRIP SUMMARY:`);
//       console.log(`   🚗 Total Distance: ${totalDistance.toFixed(2)} km`);
//       console.log(`   ⏱️  Total Travel Time: ${totalTravelTimeMinutes.toFixed(1)} minutes`);
//       console.log(`   ⏳ Total Waiting Time: ${totalWaitingTime.toFixed(1)} minutes`);
//       console.log(`   ⏱️  Total Trip Time: ${totalTimeMinutes.toFixed(1)} minutes`);
//       console.log(`   🚗 Average Speed: ${this.AVERAGE_SPEED_KMH} km/h`);
//       console.log(`   📊 Efficiency: ${((totalTravelTimeMinutes / totalTimeMinutes) * 100).toFixed(1)}% (travel time vs total time)`);
      
//       if (totalWaitingTime > 0) {
//         console.log(`\n⏳ WAITING SUMMARY:`);
//         console.log(`   📦 Total Passengers: ${driver.assignments.length}`);
//         console.log(`   ⏰ Total Waiting Time: ${totalWaitingTime.toFixed(1)} minutes`);
//         console.log(`   📊 Average Wait per Passenger: ${(totalWaitingTime / driver.assignments.length).toFixed(1)} minutes`);
//         console.log(`   🕐 Waiting Percentage: ${((totalWaitingTime / totalTimeMinutes) * 100).toFixed(1)}% of total trip time`);
//       } else {
//         console.log(`\n✅ NO WAITING TIME - All passengers ready when driver arrives`);
//       }
//     }

//     console.log('\n' + '='.repeat(80));
//     console.log('📈 SYSTEM STATISTICS');
//     console.log('='.repeat(80));

//     const totalDrivers = drivers.length;
//     const assignedDrivers = drivers.filter(d => d.assignments.length > 0).length;
//     const totalAssignments = drivers.reduce((sum, d) => sum + d.assignments.length, 0);
//     const idleDrivers = drivers.filter(d => d.assignments.length === 0).length;

//     console.log(`👥 Total Drivers: ${totalDrivers}`);
//     console.log(`✅ Assigned Drivers: ${assignedDrivers}`);
//     console.log(`❌ Idle Drivers: ${idleDrivers}`);
//     console.log(`📦 Total Assignments: ${totalAssignments}`);
//     console.log(`📊 Driver Utilization: ${((assignedDrivers / totalDrivers) * 100).toFixed(1)}%`);
//     console.log(`📊 Average Assignments per Driver: ${(totalAssignments / totalDrivers).toFixed(1)}`);

//     console.log('\n' + '='.repeat(80));
//   }


// }

// export const assignmentService = new AssignmentService();














// import { prisma } from '@utils/prisma';
// import { haversineDistance, Location } from '@utils/helpers';
// import { hungarian } from '@utils/hungarian';
// import { driverService } from './driver.js';
// import { passengerService } from './passengers.js';

// // Import types from Prisma client
// import type { Driver, Passenger, Assignment, Trip } from '@prisma/client';
// import { DriverStatus, PassengerStatus, AssignmentStatus, TripStatus } from '@prisma/client';

// interface AssignmentCandidate {
//   driverId: string;
//   passengerId: string;
//   distance: number;
//   estimatedPickupTime: Date;
//   estimatedDropoffTime: Date;
//   canMeetDeadline: boolean;
//   score: number;
//   waitingTimeMinutes: number;
// }

// interface DriverState {
//   id: string;
//   currentLocation: Location;
//   status: DriverStatus;
//   capacity: number;
//   currentPassengers: number;
//   lastDropoffTime?: Date;
//   availabilityEnd: Date;
//   idleTimeMinutes?: number;
// }

// interface PassengerState {
//   id: string;
//   pickupLocation: Location;
//   dropoffLocation: Location;
//   earliestPickupTime: Date;
//   latestPickupTime: Date;
//   groupSize: number;
//   status: PassengerStatus;
// }

// interface IdleTimeInfo {
//   driverId: string;
//   driverName: string;
//   idleTimeMinutes: number;
//   lastDropoffTime?: Date;
//   currentLocation: Location;
//   status: DriverStatus;
// }

// export class AssignmentService {
//   private readonly MAX_IDLE_TIME_MINUTES = 30;
//   private readonly AVERAGE_SPEED_KMH = 60; // Average speed for time calculations
//   private MAX_WAITING_TIME_MINUTES = 60; // Maximum time driver can wait for passenger
//   private MIN_WAITING_TIME_MINUTES = 0; // Minimum waiting time (can be 0 for no waiting)

//   /**
//    * Main assignment cycle that runs global optimization with chaining
//    */
//   async runAssignmentCycle(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Starting assignment cycle...');
      
//       let totalAssignments = 0;
//       let iteration = 1;
//       const maxIterations = 10; // Prevent infinite loops
      
//       while (iteration <= maxIterations) {
//         console.log(`[ASSIGNMENT] Starting iteration ${iteration}...`);
        
//         // Get all drivers (not just available ones) for chaining
//         const drivers = await prisma.driver.findMany({
//           where: {
//             status: {
//               in: ['IDLE', 'WAITING_POST_DROPOFF']
//             }
//           },
//           include: {
//             assignments: {
//               where: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               },
//               orderBy: {
//                 createdAt: 'desc'
//               },
//               take: 1 // Get the most recent assignment for location calculation
//             }
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers`);

//         // Get passengers without assignments
//         const unassignedPassengers = await prisma.passenger.findMany({
//           where: {
//             assignments: {
//               none: {
//                 status: {
//                   in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//                 }
//               }
//             }
//           },
//           orderBy: {
//             earliestPickupTime: 'asc'
//           }
//         });

//         console.log(`[ASSIGNMENT] Found ${unassignedPassengers.length} passengers with future pickup times`);
        
//         // Log some passenger details for debugging
//         unassignedPassengers.slice(0, 3).forEach(passenger => {
//           console.log(`[ASSIGNMENT] Passenger ${passenger.id}: earliest=${passenger.earliestPickupTime}, latest=${passenger.latestPickupTime}`);
//         });

//         // Filter passengers based on pickup time - handle both immediate and scheduled pickups
//         const now = new Date();
//         const immediatePassengers = unassignedPassengers.filter(passenger => {
//           if (!passenger.earliestPickupTime || !passenger.latestPickupTime) return false;
          
//           // Immediate pickup: passenger needs pickup within the next 2 hours
//           const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
//           return passenger.latestPickupTime <= twoHoursFromNow;
//         });

//         const scheduledPassengers = unassignedPassengers.filter(passenger => {
//           if (!passenger.earliestPickupTime || !passenger.latestPickupTime) return false;
          
//           // Scheduled pickup: passenger needs pickup more than 2 hours from now
//           const twoHoursFromNow = new Date(now.getTime() + 2 * 60 * 60 * 1000);
//           return passenger.latestPickupTime > twoHoursFromNow;
//         });

//         console.log(`[ASSIGNMENT] Immediate passengers (within 2 hours): ${immediatePassengers.length}`);
//         console.log(`[ASSIGNMENT] Scheduled passengers (future): ${scheduledPassengers.length}`);

//         // For now, focus on immediate passengers only
//         const passengersToAssign = immediatePassengers;

//         // TODO: Handle scheduled passengers separately
//         // For scheduled passengers, we would:
//         // 1. Create assignments with status SCHEDULED
//         // 2. Set estimated pickup time to passenger's earliest pickup time
//         // 3. Not start travel until closer to pickup time
//         if (scheduledPassengers.length > 0) {
//           console.log(`[ASSIGNMENT] Note: ${scheduledPassengers.length} scheduled passengers will be handled in future implementation`);
//         }

//         if (drivers.length === 0 || passengersToAssign.length === 0) {
//           console.log(`[ASSIGNMENT] No available drivers or passengers for assignment. Drivers: ${drivers.length}, Passengers: ${passengersToAssign.length}`);
//           break;
//         }

//         console.log(`[ASSIGNMENT] Found ${drivers.length} drivers and ${passengersToAssign.length} unassigned passengers`);

//         // Generate assignment candidates
//         const candidates: AssignmentCandidate[] = [];
        
//         for (const driver of drivers) {
//           // Get driver's current location (either from profile or last dropoff)
//           let driverLat = driver.currentLat;
//           let driverLng = driver.currentLng;
//           let driverCurrentTime = new Date();
          
//           // If driver has recent assignments, use the last dropoff location and time
//           if (driver.assignments.length > 0) {
//             const lastAssignment = driver.assignments[0];
//             const lastPassenger = await prisma.passenger.findUnique({
//               where: { id: lastAssignment.passengerId }
//             });
            
//             if (lastPassenger) {
//               driverLat = lastPassenger.dropoffLat;
//               driverLng = lastPassenger.dropoffLng;
//               // Estimate current time based on last dropoff
//               driverCurrentTime = new Date(lastAssignment.createdAt.getTime() + 30 * 60 * 1000); // 30 min after assignment
//             }
//           }

//           for (const passenger of passengersToAssign) {
//             // Skip if passenger has no pickup time constraints
//             if (!passenger.earliestPickupTime || !passenger.latestPickupTime) {
//               continue;
//             }
            
//             // Calculate distance and time
//             const distance = haversineDistance(
//               { lat: driverLat, lng: driverLng },
//               { lat: passenger.pickupLat, lng: passenger.pickupLng }
//             );
            
//             const timeToPickup = (distance / this.AVERAGE_SPEED_KMH) * 60; // minutes
//             const estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
            
//             // Calculate waiting time if driver arrives early
//             let waitingTimeMinutes = 0;
//             if (passenger.earliestPickupTime && estimatedPickupTime < passenger.earliestPickupTime) {
//               waitingTimeMinutes = (passenger.earliestPickupTime.getTime() - estimatedPickupTime.getTime()) / (1000 * 60);
//             }
            
//             // Check time constraints
//             const canMeetDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//             const isNotTooEarly = estimatedPickupTime >= new Date(passenger.earliestPickupTime.getTime() - 24 * 60 * 60 * 1000); // Within 24 hours before earliest
//             const waitingTimeAcceptable = waitingTimeMinutes <= this.MAX_WAITING_TIME_MINUTES;
            
//             if (canMeetDeadline && isNotTooEarly && waitingTimeAcceptable) {
//               // Calculate score
//               let score = 1000 - distance; // Base score (lower distance = higher score)
              
//               // Bonus for chaining (if driver already has assignments)
//               if (driver.assignments.length > 0) {
//                 score += 100; // Bonus for chaining
//               }
              
//               // Penalty for waiting time (prefer passengers that don't require waiting)
//               if (waitingTimeMinutes > 0) {
//                 score -= waitingTimeMinutes * 2; // Penalty of 2 points per minute of waiting
//               }
              
//               // Penalty for idle time (if driver has been idle)
//               const idleTime = Date.now() - driverCurrentTime.getTime();
//               if (idleTime > this.MAX_IDLE_TIME_MINUTES * 60 * 1000) { // 30 minutes
//                 score -= (idleTime - this.MAX_IDLE_TIME_MINUTES * 60 * 1000) / (60 * 1000); // Penalty per minute of idle time
//               }
              
//               console.log(`[ASSIGNMENT] Valid candidate: Driver ${driver.id} -> Passenger ${passenger.id}`);
//               console.log(`   Distance: ${distance.toFixed(2)} km, Time to pickup: ${timeToPickup.toFixed(1)} min`);
//               console.log(`   Estimated pickup: ${estimatedPickupTime.toLocaleString()}`);
//               console.log(`   Waiting time: ${waitingTimeMinutes.toFixed(1)} min, Score: ${score.toFixed(1)}`);
              
//               candidates.push({
//                 driverId: driver.id,
//                 passengerId: passenger.id,
//                 score: Math.max(0, score), // Ensure non-negative score
//                 distance,
//                 estimatedPickupTime,
//                 estimatedDropoffTime: new Date(estimatedPickupTime.getTime() + (distance / this.AVERAGE_SPEED_KMH) * 60 * 1000), // Estimate dropoff time
//                 canMeetDeadline: true,
//                 waitingTimeMinutes
//               });
//             } else {
//               // Log why candidate was rejected
//               if (!canMeetDeadline) {
//                 console.log(`[ASSIGNMENT] Rejected: Driver ${driver.id} -> Passenger ${passenger.id} - Cannot meet deadline`);
//                 console.log(`   Estimated pickup: ${estimatedPickupTime.toLocaleString()}, Latest: ${passenger.latestPickupTime.toLocaleString()}`);
//               } else if (!waitingTimeAcceptable) {
//                 console.log(`[ASSIGNMENT] Rejected: Driver ${driver.id} -> Passenger ${passenger.id} - Waiting time too long`);
//                 console.log(`   Waiting time: ${waitingTimeMinutes.toFixed(1)} min, Max allowed: ${this.MAX_WAITING_TIME_MINUTES} min`);
//               }
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);

//         if (candidates.length === 0) {
//           console.log('[ASSIGNMENT] No valid assignment candidates found');
//           break;
//         }

//         // Use Hungarian algorithm for optimal assignment
//         const assignments = this.runHungarianAlgorithm(candidates, drivers.length, passengersToAssign.length);
        
//         console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignments);

//         // Process assignments
//         let assignmentsMade = 0;
//         for (let i = 0; i < Math.min(drivers.length, passengersToAssign.length); i++) {
//           const assignmentIndex = assignments[i];
//           if (assignmentIndex !== -1 && assignmentIndex < candidates.length) {
//             const candidate = candidates[assignmentIndex];
            
//             console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${assignmentIndex}`);
            
//             const driver = drivers.find(d => d.id === candidate.driverId);
//             const passenger = passengersToAssign.find(p => p.id === candidate.passengerId);
            
//             if (driver && passenger) {
//               console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
//               console.log(`[ASSIGNMENT] Found candidate for assignment`);
              
//               // Create assignment and update passenger status
//               await this.createAssignmentWithPassengerUpdate(candidate);
              
//               console.log(`[ASSIGNMENT] Created assignment: Driver ${driver.id} -> Passenger ${passenger.id}`);
//               assignmentsMade++;
//               totalAssignments++;
//             }
//           }
//         }

//         console.log(`[ASSIGNMENT] Iteration ${iteration} completed. ${assignmentsMade} assignments made.`);
        
//         if (assignmentsMade === 0) {
//           console.log('[ASSIGNMENT] No assignments made in this iteration, stopping');
//           break;
//         }

//         // Simulate dropoffs for next iteration
//         console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignmentsMade} assignments...`);
//         const recentAssignments = await prisma.assignment.findMany({
//           where: {
//             status: AssignmentStatus.PENDING,
//             assignedAt: {
//               gte: new Date(Date.now() - 60 * 1000) // Last minute
//             }
//           }
//         });

//         for (const assignment of recentAssignments) {
//           // Get passenger details to get dropoff location
//           const passenger = await prisma.passenger.findUnique({
//             where: { id: assignment.passengerId }
//           });
          
//           if (passenger) {
//             // Update driver location to dropoff point
//             await prisma.driver.update({
//               where: { id: assignment.driverId },
//               data: {
//                 currentLat: passenger.dropoffLat,
//                 currentLng: passenger.dropoffLng,
//                 lastDropoffLat: passenger.dropoffLat,
//                 lastDropoffLng: passenger.dropoffLng,
//                 lastDropoffTimestamp: assignment.estimatedPickupTime, // Use estimatedPickupTime for dropoff
//                 status: DriverStatus.WAITING_POST_DROPOFF,
//                 updatedAt: new Date()
//               }
//             });
//             console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//           }
//         }

//         iteration++;
//       }
      
//       console.log(`[ASSIGNMENT] Assignment cycle completed. Total assignments: ${totalAssignments} in ${iteration - 1} iterations.`);
      
//       // Log detailed driver assignment information
//       await this.logDriverAssignments();
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error in assignment cycle:', error);
//       throw error;
//     }
//   }

//   /**
//    * Run Hungarian algorithm for optimal assignment
//    */
//   private runHungarianAlgorithm(candidates: AssignmentCandidate[], numDrivers: number, numPassengers: number): number[] {
//     if (candidates.length === 0) return [];

//     // Create cost matrix for Hungarian algorithm
//     const costMatrix: number[][] = [];
    
//     // Create a square matrix (pad with dummy assignments if needed)
//     const maxSize = Math.max(numDrivers, numPassengers);
    
//     // Get unique driver and passenger IDs in order
//     const driverIds = Array.from(new Set(candidates.map(c => c.driverId)));
//     const passengerIds = Array.from(new Set(candidates.map(c => c.passengerId)));

//     for (let i = 0; i < maxSize; i++) {
//       costMatrix[i] = [];
//       for (let j = 0; j < maxSize; j++) {
//         if (i < numDrivers && j < numPassengers) {
//           // Find candidate for this driver-passenger pair
//           const candidate = candidates.find(c => 
//             c.driverId === driverIds[i] && c.passengerId === passengerIds[j]
//           );
//           costMatrix[i][j] = candidate ? candidate.score : 999999; // High cost for invalid assignments
//         } else {
//           costMatrix[i][j] = 999999; // Dummy assignments with high cost
//         }
//       }
//     }
    
//     // Run Hungarian algorithm
//     const assignment = hungarian(costMatrix);
    
//     console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignment);
//     console.log(`[ASSIGNMENT] Drivers length: ${numDrivers}, Passengers length: ${numPassengers}`);
    
//     return assignment;
//   }

//   /**
//    * Get available drivers for assignment
//    */
//   private async getAvailableDrivers(): Promise<DriverState[]> {
//     const drivers = await prisma.driver.findMany({
//       where: {
//         status: {
//           in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//         },
//         availabilityEnd: {
//           gte: new Date()
//         }
//       },
//       include: {
//         assignedPassengers: {
//           where: {
//             status: {
//               in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP]
//             }
//           }
//         }
//       }
//     });

//     // Filter out drivers who are currently assigned to passengers
//     const availableDrivers = drivers.filter((driver: any) => 
//       driver.assignedPassengers?.length === 0
//     );

//     console.log(`[ASSIGNMENT] Found ${drivers.length} total drivers, ${availableDrivers.length} available for assignment`);

//     return availableDrivers.map((driver: any) => ({
//       id: driver.id,
//       currentLocation: this.getDriverCurrentLocation(driver),
//       status: driver.status,
//       capacity: driver.capacity,
//       currentPassengers: 0, // Reset to 0 since we filtered out assigned drivers
//       lastDropoffTime: driver.lastDropoffTimestamp || undefined,
//       availabilityEnd: driver.availabilityEnd
//     }));
//   }

//   /**
//    * Get unassigned passengers
//    */
//   private async getUnassignedPassengers(): Promise<PassengerState[]> {
//     const passengers = await prisma.passenger.findMany({
//       where: {
//         status: PassengerStatus.UNASSIGNED,
//         latestPickupTime: {
//           gte: new Date()
//         }
//       }
//     });

//     console.log(`[ASSIGNMENT] Found ${passengers.length} passengers with future pickup times`);
    
//     // Log first few passengers to understand the time data
//     for (let i = 0; i < Math.min(3, passengers.length); i++) {
//       const p = passengers[i];
//       console.log(`[ASSIGNMENT] Passenger ${p.id}: earliest=${p.earliestPickupTime?.toISOString()}, latest=${p.latestPickupTime?.toISOString()}`);
//     }

//     return passengers.map((passenger: any) => ({
//       id: passenger.id,
//       pickupLocation: { lat: passenger.pickupLat, lng: passenger.pickupLng },
//       dropoffLocation: { lat: passenger.dropoffLat, lng: passenger.dropoffLng },
//       earliestPickupTime: passenger.earliestPickupTime || new Date(),
//       latestPickupTime: passenger.latestPickupTime || new Date(Date.now() + 24 * 60 * 60 * 1000), // Default to 24 hours from now
//       groupSize: passenger.groupSize,
//       status: passenger.status
//     }));
//   }

//   /**
//    * Get driver's current location (prioritizing last dropoff location)
//    */
//   private getDriverCurrentLocation(driver: any): Location {
//     // Priority: last dropoff location > current location
//     if (driver.lastDropoffLat && driver.lastDropoffLng) {
//       return { lat: driver.lastDropoffLat, lng: driver.lastDropoffLng };
//     }
//     return { lat: driver.currentLat, lng: driver.currentLng };
//   }

//   /**
//    * Generate all possible assignment candidates with scoring
//    */
//   private async generateAssignmentCandidates(
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     const candidates: AssignmentCandidate[] = [];
//     const now = new Date();

//     for (const driver of drivers) {
//       for (const passenger of passengers) {
//         // Check capacity constraint
//         if (driver.currentPassengers + passenger.groupSize > driver.capacity) {
//           continue;
//         }

//         // Calculate distance and times
//         const distanceToPickup = haversineDistance(driver.currentLocation, passenger.pickupLocation);
//         const distanceToDropoff = haversineDistance(passenger.pickupLocation, passenger.dropoffLocation);
        
//         // Estimate travel times (in minutes)
//         const timeToPickup = (distanceToPickup / this.AVERAGE_SPEED_KMH) * 60;
//         const timeToDropoff = (distanceToDropoff / this.AVERAGE_SPEED_KMH) * 60;
        
//         // Calculate estimated times based on driver's current time
//         const driverCurrentTime = driver.lastDropoffTime || now;
//         const estimatedPickupTime = new Date(driverCurrentTime.getTime() + timeToPickup * 60 * 1000);
//         const estimatedDropoffTime = new Date(estimatedPickupTime.getTime() + timeToDropoff * 60 * 1000);
        
//         // Check if driver can meet the time constraints
//         const canMeetLatestDeadline = estimatedPickupTime <= passenger.latestPickupTime;
//         const canMeetEarliestDeadline = estimatedPickupTime >= passenger.earliestPickupTime;
        
//         // TEMPORARY: Disable time constraints for testing
//         const canMeetDeadline = true; // Allow all assignments for now
        
//         // Debug: Log first few attempts to understand the issue
//         if (candidates.length < 3) {
//           console.log(`[ASSIGNMENT] Debug - Driver ${driver.id} -> Passenger ${passenger.id}:`);
//           console.log(`  Distance: ${distanceToPickup.toFixed(2)}km, Time to pickup: ${timeToPickup.toFixed(1)}min`);
//           console.log(`  Current time: ${now.toISOString()}`);
//           console.log(`  Estimated pickup: ${estimatedPickupTime.toISOString()}`);
//           console.log(`  Earliest allowed: ${passenger.earliestPickupTime.toISOString()}`);
//           console.log(`  Latest allowed: ${passenger.latestPickupTime.toISOString()}`);
//           console.log(`  Can meet deadline: ${canMeetDeadline}`);
//         }
        
//         if (!canMeetDeadline) {
//           continue; // Skip if driver cannot meet the deadline
//         }

//         // Calculate assignment score (lower is better for Hungarian algorithm)
//         const score = this.calculateAssignmentScore({
//           driver,
//           passenger,
//           distanceToPickup,
//           distanceToDropoff,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline
//         });

//         candidates.push({
//           driverId: driver.id,
//           passengerId: passenger.id,
//           distance: distanceToPickup,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           canMeetDeadline,
//           score,
//           waitingTimeMinutes: 0 // This method doesn't calculate waiting time, so default to 0
//         });
//       }
//     }

//     console.log(`[ASSIGNMENT] Generated ${candidates.length} valid assignment candidates`);
//     return candidates;
//   }

//   /**
//    * Calculate assignment score (lower is better for optimization)
//    */
//   private calculateAssignmentScore(params: {
//     driver: DriverState;
//     passenger: PassengerState;
//     distanceToPickup: number;
//     distanceToDropoff: number;
//     estimatedPickupTime: Date;
//     estimatedDropoffTime: Date;
//     canMeetDeadline: boolean;
//   }): number {
//     const { driver, passenger, distanceToPickup, estimatedPickupTime } = params;
    
//     let score = distanceToPickup * 10; // Base score from distance
    
//     // Time constraint scoring
//     const timeToLatest = passenger.latestPickupTime.getTime() - estimatedPickupTime.getTime();
//     const timeToEarliest = estimatedPickupTime.getTime() - passenger.earliestPickupTime.getTime();
//     const timeToLatestMinutes = timeToLatest / (1000 * 60);
//     const timeToEarliestMinutes = timeToEarliest / (1000 * 60);
    
//     // Penalty for being close to latest pickup time
//     if (timeToLatestMinutes < 15) {
//       score += (15 - timeToLatestMinutes) * 10; // Higher penalty for tight timing
//     }
    
//     // Bonus for optimal timing (not too early, not too late)
//     if (timeToEarliestMinutes >= 0 && timeToEarliestMinutes <= 30) {
//       score -= Math.min(timeToEarliestMinutes * 0.3, 5); // Bonus for good timing
//     }
    
//     // Penalty for being too early
//     if (timeToEarliestMinutes < 0) {
//       score += Math.abs(timeToEarliestMinutes) * 2; // Penalty for being too early
//     }
    
//     // Bonus for drivers who just dropped off (encourage chaining)
//     if (driver.status === DriverStatus.WAITING_POST_DROPOFF) {
//       const idleTime = driver.lastDropoffTime ? 
//         (Date.now() - driver.lastDropoffTime.getTime()) / (1000 * 60) : 0;
      
//       if (idleTime < 5) {
//         score -= 20; // Big bonus for immediate chaining
//       } else if (idleTime < 15) {
//         score -= 10; // Medium bonus for quick chaining
//       } else if (idleTime > this.MAX_IDLE_TIME_MINUTES) {
//         score += (idleTime - this.MAX_IDLE_TIME_MINUTES) * 3; // Higher penalty for excessive idle time
//       }
//     }
    
//     return Math.max(0, score); // Ensure non-negative score
//   }

//   /**
//    * Run global optimization using Hungarian algorithm
//    */
//   private async runGlobalOptimization(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): Promise<AssignmentCandidate[]> {
//     if (candidates.length === 0) return [];

//     // Create cost matrix for Hungarian algorithm
//     const costMatrix = this.createCostMatrix(candidates, drivers, passengers);
    
//     // Run Hungarian algorithm
//     const assignment = hungarian(costMatrix);
    
//     // Convert assignment result back to candidates
//     const optimalAssignments: AssignmentCandidate[] = [];
//     console.log(`[ASSIGNMENT] Hungarian algorithm result:`, assignment);
//     console.log(`[ASSIGNMENT] Drivers length: ${drivers.length}, Passengers length: ${passengers.length}`);
    
//     for (let i = 0; i < assignment.length && i < drivers.length; i++) {
//       const passengerIndex = assignment[i];
//       console.log(`[ASSIGNMENT] Processing assignment ${i}: driver ${i}, passenger ${passengerIndex}`);
      
//       if (passengerIndex < passengers.length) {
//         const driver = drivers[i];
//         const passenger = passengers[passengerIndex];
        
//         // Safety check to ensure both driver and passenger exist
//         if (driver && passenger) {
//           console.log(`[ASSIGNMENT] Found valid driver ${driver.id} and passenger ${passenger.id}`);
          
//           // Find the corresponding candidate
//           const candidate = candidates.find(c => 
//             c.driverId === driver.id && c.passengerId === passenger.id
//           );
          
//           if (candidate) {
//             console.log(`[ASSIGNMENT] Found candidate for assignment`);
//             optimalAssignments.push(candidate);
//           } else {
//             console.log(`[ASSIGNMENT] No candidate found for driver ${driver.id} and passenger ${passenger.id}`);
//           }
//         } else {
//           console.log(`[ASSIGNMENT] Missing driver or passenger: driver=${!!driver}, passenger=${!!passenger}`);
//         }
//       } else {
//         console.log(`[ASSIGNMENT] Passenger index ${passengerIndex} out of range (max: ${passengers.length})`);
//       }
//     }

//     return optimalAssignments;
//   }

//   /**
//    * Create cost matrix for Hungarian algorithm
//    */
//   private createCostMatrix(
//     candidates: AssignmentCandidate[],
//     drivers: DriverState[],
//     passengers: PassengerState[]
//   ): number[][] {
//     const matrix: number[][] = [];
    
//     // Create a square matrix (pad with dummy assignments if needed)
//     const maxSize = Math.max(drivers.length, passengers.length);
    
//     for (let i = 0; i < maxSize; i++) {
//       matrix[i] = [];
//       for (let j = 0; j < maxSize; j++) {
//         if (i < drivers.length && j < passengers.length) {
//           // Find candidate for this driver-passenger pair
//           const candidate = candidates.find(c => 
//             c.driverId === drivers[i].id && c.passengerId === passengers[j].id
//           );
//           matrix[i][j] = candidate ? candidate.score : 999999; // High cost for invalid assignments
//         } else {
//           matrix[i][j] = 999999; // Dummy assignments with high cost
//         }
//       }
//     }
    
//     return matrix;
//   }

//   /**
//    * Execute the optimal assignments
//    */
//   private async executeAssignments(assignments: AssignmentCandidate[]): Promise<void> {
//     for (const assignment of assignments) {
//       try {
//         await this.createAssignment(assignment);
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Failed to create assignment for driver ${assignment.driverId} and passenger ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Create a single assignment
//    */
//   private async createAssignment(candidate: AssignmentCandidate): Promise<void> {
//     const { driverId, passengerId, estimatedPickupTime, estimatedDropoffTime } = candidate;

//     // Use transaction to ensure data consistency
//     await prisma.$transaction(async (tx: any) => {
//       // 1. Update passenger status
//       await tx.passenger.update({
//         where: { id: passengerId },
//         data: {
//           status: PassengerStatus.ASSIGNED,
//           assignedDriverId: driverId,
//           updatedAt: new Date()
//         }
//       });

//       // 2. Update driver status
//       await tx.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.EN_ROUTE_TO_PICKUP,
//           updatedAt: new Date()
//         }
//       });

//       // 3. Create assignment record
//       await tx.assignment.create({
//         data: {
//           driverId,
//           passengerId,
//           estimatedPickupTime,
//           estimatedDropoffTime,
//           status: AssignmentStatus.PENDING,
//           assignedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Created assignment: Driver ${driverId} -> Passenger ${passengerId}`);
//     });
//   }

//   /**
//    * Create assignment and update passenger status
//    */
//   private async createAssignmentWithPassengerUpdate(candidate: AssignmentCandidate): Promise<void> {
//     const { driverId, passengerId, estimatedPickupTime, estimatedDropoffTime } = candidate;

//     // Use transaction to ensure data consistency
//     await prisma.$transaction(async (tx) => {
//       // 1. Update passenger status to ASSIGNED
//       await tx.passenger.update({
//         where: { id: passengerId },
//         data: {
//           status: PassengerStatus.ASSIGNED,
//           assignedDriverId: driverId,
//           updatedAt: new Date()
//         }
//       });

//       // 2. Update driver status
//       await tx.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.EN_ROUTE_TO_PICKUP,
//           updatedAt: new Date()
//         }
//       });

//       // 3. Create assignment record
//       await tx.assignment.create({
//         data: {
//           driverId,
//           passengerId,
//           status: AssignmentStatus.PENDING,
//           assignedAt: new Date(),
//           estimatedPickupTime: candidate.estimatedPickupTime,
//           estimatedDropoffTime: candidate.estimatedDropoffTime
//         }
//       });

//       console.log(`[ASSIGNMENT] Created assignment and updated passenger status: Driver ${driverId} -> Passenger ${passengerId}`);
//     });
//   }

//   /**
//    * Complete an assignment and update passenger status to DROPPED_OFF
//    */


//   /**
//    * Handle post-dropoff logic - update driver location and status
//    */
//   async handlePostDropoff(driverId: string, dropoffLocation: Location): Promise<void> {
//     try {
//       await prisma.driver.update({
//         where: { id: driverId },
//         data: {
//           status: DriverStatus.WAITING_POST_DROPOFF,
//           lastDropoffTimestamp: new Date(),
//           lastDropoffLat: dropoffLocation.lat,
//           lastDropoffLng: dropoffLocation.lng,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driverId} marked as waiting post-dropoff at ${dropoffLocation.lat}, ${dropoffLocation.lng}`);
//     } catch (error) {
//       console.error(`[ASSIGNMENT] Error handling post-dropoff for driver ${driverId}:`, error);
//       throw error;
//     }
//   }

//   /**
//    * Check and handle idle time expiration
//    */
//   async checkIdleTimeExpiration(): Promise<void> {
//     const thirtyMinutesAgo = new Date(Date.now() - this.MAX_IDLE_TIME_MINUTES * 60 * 1000);
    
//     const idleDrivers = await prisma.driver.findMany({
//       where: {
//         status: DriverStatus.WAITING_POST_DROPOFF,
//         lastDropoffTimestamp: {
//           lt: thirtyMinutesAgo
//         }
//       }
//     });

//     for (const driver of idleDrivers) {
//       await prisma.driver.update({
//         where: { id: driver.id },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });

//       console.log(`[ASSIGNMENT] Driver ${driver.id} idle time expired, status reset to IDLE`);
//     }
//   }

//   /**
//    * Simulate dropoffs and update driver locations for chained assignments
//    */
//   private async simulateDropoffsAndUpdateLocations(assignments: AssignmentCandidate[]): Promise<void> {
//     console.log(`[ASSIGNMENT] Simulating dropoffs for ${assignments.length} assignments...`);
    
//     for (const assignment of assignments) {
//       try {
//         // Get the passenger details to get dropoff location
//         const passenger = await prisma.passenger.findUnique({
//           where: { id: assignment.passengerId }
//         });
        
//         if (passenger) {
//           // Update driver location to passenger's dropoff location
//           await prisma.driver.update({
//             where: { id: assignment.driverId },
//             data: {
//               currentLat: passenger.dropoffLat,
//               currentLng: passenger.dropoffLng,
//               lastDropoffLat: passenger.dropoffLat,
//               lastDropoffLng: passenger.dropoffLng,
//               lastDropoffTimestamp: assignment.estimatedDropoffTime,
//               status: DriverStatus.WAITING_POST_DROPOFF,
//               updatedAt: new Date()
//             }
//           });
          
//           console.log(`[ASSIGNMENT] Updated driver ${assignment.driverId} location to dropoff point (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         }
//       } catch (error) {
//         console.error(`[ASSIGNMENT] Error simulating dropoff for assignment ${assignment.driverId} -> ${assignment.passengerId}:`, error);
//       }
//     }
//   }

//   /**
//    * Reset assignment system for testing (unassign all passengers and reset drivers)
//    */
//   async resetAssignmentSystem(): Promise<void> {
//     try {
//       console.log('[ASSIGNMENT] Resetting assignment system...');
      
//       // Reset all passengers to unassigned
//       await prisma.passenger.updateMany({
//         where: {
//           status: {
//             in: [PassengerStatus.ASSIGNED, PassengerStatus.PICKED_UP, PassengerStatus.DROPPED_OFF]
//           }
//         },
//         data: {
//           status: PassengerStatus.UNASSIGNED,
//           assignedDriverId: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Reset all drivers to idle
//       await prisma.driver.updateMany({
//         where: {
//           status: {
//             in: [DriverStatus.EN_ROUTE_TO_PICKUP, DriverStatus.EN_ROUTE_TO_DROPOFF, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         },
//         data: {
//           status: DriverStatus.IDLE,
//           lastDropoffTimestamp: null,
//           lastDropoffLat: null,
//           lastDropoffLng: null,
//           updatedAt: new Date()
//         }
//       });
      
//       // Delete all assignments
//       await prisma.assignment.deleteMany({});
      
//       console.log('[ASSIGNMENT] Assignment system reset completed');
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error resetting assignment system:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get assignment statistics
//    */
//   async getAssignmentStats(): Promise<{
//     totalDrivers: number;
//     availableDrivers: number;
//     totalPassengers: number;
//     unassignedPassengers: number;
//     activeAssignments: number;
//   }> {
//     const [
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     ] = await Promise.all([
//       prisma.driver.count(),
//       prisma.driver.count({
//         where: {
//           status: {
//             in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         }
//       }),
//       prisma.passenger.count(),
//       prisma.passenger.count({
//         where: { status: PassengerStatus.UNASSIGNED }
//       }),
//       prisma.assignment.count({
//         where: {
//           status: {
//             in: [AssignmentStatus.PENDING, AssignmentStatus.CONFIRMED, AssignmentStatus.IN_PROGRESS]
//           }
//         }
//       })
//     ]);

//     return {
//       totalDrivers,
//       availableDrivers,
//       totalPassengers,
//       unassignedPassengers,
//       activeAssignments
//     };
//   }

//   /**
//    * Get idle time information for all drivers
//    */
//   async getDriverIdleTimes(): Promise<IdleTimeInfo[]> {
//     try {
//       const drivers = await prisma.driver.findMany({
//         where: {
//           status: {
//             in: [DriverStatus.IDLE, DriverStatus.WAITING_POST_DROPOFF]
//           }
//         },
//         include: {
//           assignments: {
//             where: {
//               status: AssignmentStatus.COMPLETED
//             },
//             orderBy: {
//               actualDropoffTime: 'desc'
//             },
//             take: 1
//           }
//         }
//       });

//       const now = new Date();
//       const idleTimeInfo: IdleTimeInfo[] = [];

//       for (const driver of drivers) {
//         let idleTimeMinutes = 0;
//         let lastDropoffTime: Date | undefined;

//         if (driver.status === DriverStatus.WAITING_POST_DROPOFF && driver.lastDropoffTimestamp) {
//           // Driver is in post-dropoff waiting period
//           lastDropoffTime = driver.lastDropoffTimestamp;
//           idleTimeMinutes = Math.floor((now.getTime() - driver.lastDropoffTimestamp.getTime()) / (1000 * 60));
//         } else if (driver.status === DriverStatus.IDLE) {
//           // Driver is idle - check last completed assignment
//           if (driver.assignments.length > 0) {
//             const lastAssignment = driver.assignments[0];
//             if (lastAssignment.actualDropoffTime) {
//               lastDropoffTime = lastAssignment.actualDropoffTime;
//               idleTimeMinutes = Math.floor((now.getTime() - lastAssignment.actualDropoffTime.getTime()) / (1000 * 60));
//             }
//           }
//         }

//         idleTimeInfo.push({
//           driverId: driver.id,
//           driverName: driver.name,
//           idleTimeMinutes,
//           lastDropoffTime,
//           currentLocation: {
//             lat: driver.currentLat,
//             lng: driver.currentLng
//           },
//           status: driver.status
//         });
//       }

//       // Sort by idle time (longest first)
//       return idleTimeInfo.sort((a, b) => b.idleTimeMinutes - a.idleTimeMinutes);
//     } catch (error) {
//       console.error('[ASSIGNMENT] Error getting driver idle times:', error);
//       throw error;
//     }
//   }

//   /**
//    * Get detailed idle time report
//    */
//   async getIdleTimeReport(): Promise<{
//     totalDrivers: number;
//     idleDrivers: number;
//     waitingPostDropoff: number;
//     averageIdleTime: number;
//     maxIdleTime: number;
//     driversByIdleTime: IdleTimeInfo[];
//   }> {
//     const idleTimeInfo = await this.getDriverIdleTimes();
    
//     const totalDrivers = idleTimeInfo.length;
//     const idleDrivers = idleTimeInfo.filter(d => d.status === DriverStatus.IDLE).length;
//     const waitingPostDropoff = idleTimeInfo.filter(d => d.status === DriverStatus.WAITING_POST_DROPOFF).length;
    
//     const totalIdleTime = idleTimeInfo.reduce((sum, driver) => sum + driver.idleTimeMinutes, 0);
//     const averageIdleTime = totalDrivers > 0 ? Math.round(totalIdleTime / totalDrivers) : 0;
//     const maxIdleTime = Math.max(...idleTimeInfo.map(d => d.idleTimeMinutes), 0);

//     return {
//       totalDrivers,
//       idleDrivers,
//       waitingPostDropoff,
//       averageIdleTime,
//       maxIdleTime,
//       driversByIdleTime: idleTimeInfo
//     };
//   }

//   /**
//    * Log detailed driver assignment information with timing and distance
//    */
//   /**
//    * Get current waiting time constraints
//    */
//   public getWaitingTimeConstraints(): {
//     maxWaitingTimeMinutes: number;
//     minWaitingTimeMinutes: number;
//     averageSpeedKmh: number;
//   } {
//     return {
//       maxWaitingTimeMinutes: this.MAX_WAITING_TIME_MINUTES,
//       minWaitingTimeMinutes: this.MIN_WAITING_TIME_MINUTES,
//       averageSpeedKmh: this.AVERAGE_SPEED_KMH
//     };
//   }

//   /**
//    * Update waiting time constraints
//    */
//   public updateWaitingTimeConstraints(maxWaitingMinutes: number, minWaitingMinutes: number = 0): void {
//     this.MAX_WAITING_TIME_MINUTES = maxWaitingMinutes;
//     this.MIN_WAITING_TIME_MINUTES = minWaitingMinutes;
//     console.log(`[ASSIGNMENT] Updated waiting time constraints: Max=${maxWaitingMinutes}min, Min=${minWaitingMinutes}min`);
//   }

//   public async logDriverAssignments(): Promise<void> {
//     console.log('\n' + '='.repeat(80));
//     console.log('🚗 DRIVER ASSIGNMENT DETAILED REPORT');
//     console.log('='.repeat(80));

//     // Get all drivers with their assignments
//     const drivers = await prisma.driver.findMany({
//       include: {
//         assignments: {
//           where: {
//             status: {
//               in: ['PENDING', 'CONFIRMED', 'IN_PROGRESS']
//             }
//           },
//           include: {
//             passenger: true
//           },
//           orderBy: {
//             assignedAt: 'asc'
//           }
//         }
//       },
//       orderBy: {
//         name: 'asc'
//       }
//     });

//     for (const driver of drivers) {
//       console.log(`\n📋 DRIVER: ${driver.name} (${driver.id})`);
//       console.log(`📍 Current Location: (${driver.currentLat}, ${driver.currentLng})`);
//       console.log(`🕒 Status: ${driver.status}`);
      
//       if (driver.lastDropoffTimestamp) {
//         const idleTime = Math.floor((Date.now() - driver.lastDropoffTimestamp.getTime()) / (1000 * 60));
//         console.log(`⏰ Last Dropoff: ${driver.lastDropoffTimestamp.toLocaleString()}`);
//         console.log(`😴 Idle Time: ${idleTime} minutes`);
//       }

//       if (driver.assignments.length === 0) {
//         console.log(`❌ No assignments`);
//         continue;
//       }

//       console.log(`\n📦 ASSIGNMENTS (${driver.assignments.length}):`);
//       console.log('-'.repeat(80));

//       let currentTime = new Date();
//       let currentLocation = { lat: driver.currentLat, lng: driver.currentLng };
//       let totalWaitingTime = 0;

//       for (let i = 0; i < driver.assignments.length; i++) {
//         const assignment = driver.assignments[i];
//         const passenger = assignment.passenger;

//         console.log(`\n${i + 1}. Passenger: ${passenger.name} (${passenger.id})`);
//         console.log(`   📍 Pickup: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`   🎯 Dropoff: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         console.log(`   ⏰ Earliest Pickup: ${passenger.earliestPickupTime?.toLocaleString() || 'Not set'}`);
//         console.log(`   ⏰ Latest Pickup: ${passenger.latestPickupTime?.toLocaleString() || 'Not set'}`);

//         // Calculate distance from current location to pickup
//         const distanceToPickup = haversineDistance(
//           currentLocation,
//           { lat: passenger.pickupLat, lng: passenger.pickupLng }
//         );

//         // Calculate time to pickup
//         const timeToPickupMinutes = (distanceToPickup / this.AVERAGE_SPEED_KMH) * 60;
//         const estimatedPickupTime = new Date(currentTime.getTime() + timeToPickupMinutes * 60 * 1000);

//         // Calculate distance from pickup to dropoff
//         const distancePickupToDropoff = haversineDistance(
//           { lat: passenger.pickupLat, lng: passenger.pickupLng },
//           { lat: passenger.dropoffLat, lng: passenger.dropoffLng }
//         );

//         // Calculate time from pickup to dropoff
//         const timePickupToDropoffMinutes = (distancePickupToDropoff / this.AVERAGE_SPEED_KMH) * 60;
//         const estimatedDropoffTime = new Date(estimatedPickupTime.getTime() + timePickupToDropoffMinutes * 60 * 1000);

//         // Calculate waiting time if driver arrives early
//         let waitingTimeMinutes = 0;
//         let actualPickupTime = estimatedPickupTime;
//         if (passenger.earliestPickupTime && estimatedPickupTime < passenger.earliestPickupTime) {
//           waitingTimeMinutes = (passenger.earliestPickupTime.getTime() - estimatedPickupTime.getTime()) / (1000 * 60);
//           actualPickupTime = passenger.earliestPickupTime;
//           totalWaitingTime += waitingTimeMinutes;
//         }

//         // Update dropoff time if there was waiting
//         const actualDropoffTime = new Date(actualPickupTime.getTime() + timePickupToDropoffMinutes * 60 * 1000);

//         console.log(`\n   🚗 STEP 1: DRIVER TO PICKUP`);
//         console.log(`      📍 From: (${currentLocation.lat.toFixed(4)}, ${currentLocation.lng.toFixed(4)})`);
//         console.log(`      📍 To: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`      🚗 Distance: ${distanceToPickup.toFixed(2)} km`);
//         console.log(`      ⏱️  Travel Time: ${timeToPickupMinutes.toFixed(1)} minutes`);
//         console.log(`      🕐 Departure: ${currentTime.toLocaleString()}`);
//         console.log(`      🕐 Arrival: ${estimatedPickupTime.toLocaleString()}`);

//         if (waitingTimeMinutes > 0) {
//           console.log(`\n   ⏳ WAITING FOR PASSENGER: ${passenger.name}`);
//           console.log(`      ⏰ Wait Time: ${waitingTimeMinutes.toFixed(1)} minutes`);
//           console.log(`      🕐 Wait From: ${estimatedPickupTime.toLocaleString()}`);
//           console.log(`      🕐 Wait Until: ${actualPickupTime.toLocaleString()}`);
//           console.log(`      📍 Waiting Location: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//           console.log(`      🚗 Driver Status: Waiting at pickup location`);
//         } else {
//           console.log(`\n   ✅ NO WAITING NEEDED`);
//           console.log(`      🕐 Driver arrives at: ${estimatedPickupTime.toLocaleString()}`);
//           console.log(`      ⏰ Passenger ready at: ${passenger.earliestPickupTime?.toLocaleString() || 'No time constraint'}`);
//         }

//         console.log(`\n   🚗 STEP 2: PICKUP TO DROPOFF`);
//         console.log(`      📍 From: (${passenger.pickupLat}, ${passenger.pickupLng})`);
//         console.log(`      📍 To: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//         console.log(`      🚗 Distance: ${distancePickupToDropoff.toFixed(2)} km`);
//         console.log(`      ⏱️  Travel Time: ${timePickupToDropoffMinutes.toFixed(1)} minutes`);
//         console.log(`      🕐 Departure: ${actualPickupTime.toLocaleString()}`);
//         console.log(`      🕐 Arrival: ${actualDropoffTime.toLocaleString()}`);

//         // Calculate chaining to next passenger (if not the last assignment)
//         if (i < driver.assignments.length - 1) {
//           const nextAssignment = driver.assignments[i + 1];
//           const nextPassenger = nextAssignment.passenger;
          
//           // Time from current dropoff to next pickup
//           const distanceToNextPickup = haversineDistance(
//             { lat: passenger.dropoffLat, lng: passenger.dropoffLng },
//             { lat: nextPassenger.pickupLat, lng: nextPassenger.pickupLng }
//           );
          
//           const timeToNextPickupMinutes = (distanceToNextPickup / this.AVERAGE_SPEED_KMH) * 60;
//           const nextPickupTime = new Date(actualDropoffTime.getTime() + timeToNextPickupMinutes * 60 * 1000);
          
//           console.log(`\n   🔗 STEP 3: CHAINING TO NEXT PASSENGER`);
//           console.log(`      📍 From: (${passenger.dropoffLat}, ${passenger.dropoffLng})`);
//           console.log(`      📍 To: (${nextPassenger.pickupLat}, ${nextPassenger.pickupLng})`);
//           console.log(`      🚗 Distance: ${distanceToNextPickup.toFixed(2)} km`);
//           console.log(`      ⏱️  Travel Time: ${timeToNextPickupMinutes.toFixed(1)} minutes`);
//           console.log(`      🕐 Departure: ${actualDropoffTime.toLocaleString()}`);
//           console.log(`      🕐 Arrival: ${nextPickupTime.toLocaleString()}`);
//         }

//         // Update current time and location for next iteration
//         currentTime = actualDropoffTime;
//         currentLocation = { lat: passenger.dropoffLat, lng: passenger.dropoffLng };
//       }

//       // Calculate total trip statistics
//       const totalDistance = driver.assignments.reduce((total, assignment, index) => {
//         const passenger = assignment.passenger;
//         let distance = 0;
        
//         if (index === 0) {
//           // First assignment: distance from current location to pickup
//           distance += haversineDistance(
//             { lat: driver.currentLat, lng: driver.currentLng },
//             { lat: passenger.pickupLat, lng: passenger.pickupLng }
//           );
//         } else {
//           // Distance from previous dropoff to current pickup
//           const prevPassenger = driver.assignments[index - 1].passenger;
//           distance += haversineDistance(
//             { lat: prevPassenger.dropoffLat, lng: prevPassenger.dropoffLng },
//             { lat: passenger.pickupLat, lng: passenger.pickupLng }
//           );
//         }
        
//         // Distance from pickup to dropoff
//         distance += haversineDistance(
//           { lat: passenger.pickupLat, lng: passenger.pickupLng },
//           { lat: passenger.dropoffLat, lng: passenger.dropoffLng }
//         );
        
//         return total + distance;
//       }, 0);

//       const totalTravelTimeMinutes = (totalDistance / this.AVERAGE_SPEED_KMH) * 60;
//       const totalTimeMinutes = totalTravelTimeMinutes + totalWaitingTime;
      
//       console.log(`\n📊 TRIP SUMMARY:`);
//       console.log(`   🚗 Total Distance: ${totalDistance.toFixed(2)} km`);
//       console.log(`   ⏱️  Total Travel Time: ${totalTravelTimeMinutes.toFixed(1)} minutes`);
//       console.log(`   ⏳ Total Waiting Time: ${totalWaitingTime.toFixed(1)} minutes`);
//       console.log(`   ⏱️  Total Trip Time: ${totalTimeMinutes.toFixed(1)} minutes`);
//       console.log(`   🚗 Average Speed: ${this.AVERAGE_SPEED_KMH} km/h`);
//       console.log(`   📊 Efficiency: ${((totalTravelTimeMinutes / totalTimeMinutes) * 100).toFixed(1)}% (travel time vs total time)`);
      
//       if (totalWaitingTime > 0) {
//         console.log(`\n⏳ WAITING SUMMARY:`);
//         console.log(`   📦 Total Passengers: ${driver.assignments.length}`);
//         console.log(`   ⏰ Total Waiting Time: ${totalWaitingTime.toFixed(1)} minutes`);
//         console.log(`   📊 Average Wait per Passenger: ${(totalWaitingTime / driver.assignments.length).toFixed(1)} minutes`);
//         console.log(`   🕐 Waiting Percentage: ${((totalWaitingTime / totalTimeMinutes) * 100).toFixed(1)}% of total trip time`);
//       } else {
//         console.log(`\n✅ NO WAITING TIME - All passengers ready when driver arrives`);
//       }
//     }

//     console.log('\n' + '='.repeat(80));
//     console.log('📈 SYSTEM STATISTICS');
//     console.log('='.repeat(80));

//     const totalDrivers = drivers.length;
//     const assignedDrivers = drivers.filter(d => d.assignments.length > 0).length;
//     const totalAssignments = drivers.reduce((sum, d) => sum + d.assignments.length, 0);
//     const idleDrivers = drivers.filter(d => d.assignments.length === 0).length;

//     console.log(`👥 Total Drivers: ${totalDrivers}`);
//     console.log(`✅ Assigned Drivers: ${assignedDrivers}`);
//     console.log(`❌ Idle Drivers: ${idleDrivers}`);
//     console.log(`📦 Total Assignments: ${totalAssignments}`);
//     console.log(`📊 Driver Utilization: ${((assignedDrivers / totalDrivers) * 100).toFixed(1)}%`);
//     console.log(`📊 Average Assignments per Driver: ${(totalAssignments / totalDrivers).toFixed(1)}`);

//     console.log('\n' + '='.repeat(80));
//   }


// }

// export const assignmentService = new AssignmentService();



