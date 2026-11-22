#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <IOKit/IOKitLib.h>

int main(int argc, char **argv) {
    io_service_t svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AsusSMC"));
    if (!svc) {
        fprintf(stderr, "AsusSMC service not found\n");
        return 1;
    }

    io_connect_t conn = 0;
    kern_return_t kr = IOServiceOpen(svc, mach_task_self(), 0, &conn);
    IOObjectRelease(svc);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "IOServiceOpen failed 0x%x\n", kr);
        return 2;
    }

    uint64_t level = 0;
    uint32_t outCount = 1;
    IOConnectCallScalarMethod(conn, 1, NULL, 0, &level, &outCount);

    if (argc > 1 && strcmp(argv[1], "+") == 0) {
        level = (level + 1) % 4;
    } else if (argc > 1 && strcmp(argv[1], "-") == 0) {
        level = (level + 3) % 4;
    } else if (argc > 1) {
        level = (uint64_t)atoi(argv[1]);
        if (level > 3) level = 3;
    }

    uint64_t in[1] = { level };
    kr = IOConnectCallScalarMethod(conn, 0, in, 1, NULL, NULL);
    IOServiceClose(conn);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "set level failed 0x%x\n", kr);
        return 3;
    }
    printf("%llu\n", (unsigned long long)level);
    return 0;
}
