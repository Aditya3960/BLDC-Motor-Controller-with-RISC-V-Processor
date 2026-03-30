// Simple immediate test - no delays
#define REG_DUTY      (*(volatile int*)0x40000000)
#define REG_ENABLE    (*(volatile int*)0x40000004)
#define REG_MODE      (*(volatile int*)0x40000008)
#define REG_CURRENT   (*(volatile int*)0x40000010)
#define REG_VOLTAGE   (*(volatile int*)0x40000014)

int main() {
    // Write immediately - no delays
    REG_CURRENT = 1500;
    REG_VOLTAGE = 2500;
    REG_MODE = 0;
   REG_DUTY = 1000;    
    REG_ENABLE = 1;
    
    // Infinite loop
    while(1);
    
    return 0;
}
