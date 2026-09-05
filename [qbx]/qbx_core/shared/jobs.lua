---Job names must be lower case (top level table key)
---@type table<string, Job>
return {
    ['unemployed'] = {
        label = 'Civilian',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Freelancer',
                payment = 10
            },
        },
    },
    ['lspd'] = {
        label = 'LSPD',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Cadet',
                payment = 40
            },
            [1] = {
                name = 'Solo Cadet',
                payment = 50
            },
            [2] = {
                name = 'Officer',
                payment = 65
            },
            [3] = {
                name = 'Senior Officer',
                payment = 75
            },
            [4] = {
                name = 'Corporal',
                payment = 85
            },
            [5] = {
                name = 'Sergeant',
                payment = 100
            },
            [6] = {
                name = 'Head Sergeant',
                payment = 110
            },
            [7] = {
                name = 'Lieutenant',
                payment = 125
            },
            [8] = {
                name = 'Captain',
                payment = 140
            },
            [9] = {
                name = 'Commander',
                payment = 155
            },
            [10] = {
                name = 'Dep. Chief of Police',
                payment = 170
            },
            [11] = {
                name = 'Asst. Chief of Police',
                payment = 190
            },
            [12] = {
                name = 'Chief of Police',
                isboss = true,
                bankAuth = true,
                payment = 210
            },
        },
    },
    ['bcso'] = {
        label = 'BCSO',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Deputy',
                payment = 30
            },
            [1] = {
                name = 'Senior Deputy',
                payment = 40
            },
            [2] = {
                name = 'Corporal',
                payment = 50
            },
            [3] = {
                name = 'Sergeant',
                payment = 60
            },
            [4] = {
                name = 'Staff Sergeant',
                payment = 70
            },
            [5] = {
                name = 'Lieutenant',
                payment = 80
            },
            [6] = {
                name = 'Major',
                payment = 90
            },
            [7] = {
                name = 'Commander',
                payment = 100
            },
            [8] = {
                name = 'Chief Deputy',
                payment = 115
            },
            [9] = {
                name = 'Undersheriff',
                payment = 135
            },
            [10] = {
                name = 'Sheriff',
                isboss = true,
                bankAuth = true,
                payment = 160
            },
        },
    },
    ['sasp'] = {
        label = 'SASP',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Trooper',
                payment = 100
            },
            [1] = {
                name = 'Senior Trooper SGT',
                payment = 130
            },
            [2] = {
                name = 'Trooper Sergeant',
                payment = 160
            },
            [3] = {
                name = 'Trooper Lieutenant',
                payment = 190
            },
            [4] = {
                name = 'Assistant Commissioner',
                payment = 220
            },
            [5] = {
                name = 'Deputy Commissioner',
                payment = 260
            },
            [6] = {
                name = 'Commissioner',
                isboss = true,
                bankAuth = true,
                payment = 300
            },
        },
    },
    ['saspr'] = {
        label = 'SASPR',
        type = 'leo',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Ranger',
                payment = 35
            },
            [1] = {
                name = 'Senior Ranger',
                payment = 45
            },
            [2] = {
                name = 'Corporal',
                payment = 55
            },
            [3] = {
                name = 'Sergeant',
                payment = 65
            },
            [4] = {
                name = 'Head Sergeant',
                payment = 75
            },
            [5] = {
                name = 'Lieutenant',
                payment = 85
            },
            [6] = {
                name = 'Captain',
                payment = 95
            },
            [7] = {
                name = 'Lead Ranger',
                payment = 110
            },
            [8] = {
                name = 'Asst. Game Warden',
                payment = 130
            },
            [9] = {
                name = 'Game Warden',
                isboss = true,
                bankAuth = true,
                payment = 155
            },
        },
    },
    ['ambulance'] = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Paramedic',
                payment = 75
            },
            [2] = {
                name = 'Doctor',
                payment = 100
            },
            [3] = {
                name = 'Surgeon',
                payment = 125
            },
            [4] = {
                name = 'Chief',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['realestate'] = {
        label = 'Real Estate',
        type = 'realestate',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'House Sales',
                payment = 75
            },
            [2] = {
                name = 'Business Sales',
                payment = 100
            },
            [3] = {
                name = 'Broker',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['taxi'] = {
        label = 'Taxi',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Driver',
                payment = 75
            },
            [2] = {
                name = 'Event Driver',
                payment = 100
            },
            [3] = {
                name = 'Sales',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['bus'] = {
        label = 'Bus',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['cardealer'] = {
        label = 'Vehicle Dealer',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Showroom Sales',
                payment = 75
            },
            [2] = {
                name = 'Business Sales',
                payment = 100
            },
            [3] = {
                name = 'Finance',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['mechanic'] = {
        label = 'Mechanic',
        type = 'mechanic',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Recruit',
                payment = 50
            },
            [1] = {
                name = 'Novice',
                payment = 75
            },
            [2] = {
                name = 'Experienced',
                payment = 100
            },
            [3] = {
                name = 'Advanced',
                payment = 125
            },
            [4] = {
                name = 'Manager',
                isboss = true,
                bankAuth = true,
                payment = 150
            },
        },
    },
    ['judge'] = {
        label = 'Honorary',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Judge',
                payment = 100
            },
        },
    },
    ['lawyer'] = {
        label = 'Law Firm',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Associate',
                payment = 50
            },
        },
    },
    ['reporter'] = {
        label = 'Reporter',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Journalist',
                payment = 50
            },
        },
    },
    ['trucker'] = {
        label = 'Trucker',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['tow'] = {
        label = 'Towing',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Driver',
                payment = 50
            },
        },
    },
    ['garbage'] = {
        label = 'Garbage',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Collector',
                payment = 50
            },
        },
    },
    ['vineyard'] = {
        label = 'Vineyard',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Picker',
                payment = 50
            },
        },
    },
    ['hotdog'] = {
        label = 'Hotdog',
        defaultDuty = true,
        offDutyPay = false,
        grades = {
            [0] = {
                name = 'Sales',
                payment = 50
            },
        },
    },
}
