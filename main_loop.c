// General function:
// 1. Check if there are any delivered puzzles via delivered_puzzles array
// 2. If there are, go to that planet and solve its puzzles
// 3. If not, find the nearest puzzle without a pending puzzle request and request a puzzle

// C code
int main()
{
	struct planet_info_t planets[5]; 
	int pending_requests[5];
	int delivered_puzzles[5];
	struct node puzzles[5]; // each array entry is a pointer to 8kb of reserved memory

	// initialize our arrays
	int i;
	for (i = 0; i < 5; i++) {
		pending_requests[i] = 0;
		delivered_puzzles[i] = 0;
	}

	while (1) {
		int j = -1;
		for (i = 0; i < 5; i++) {
			if (delivered_puzzles[i]) {
				j = i;
				break;
			}
		}

		if (j >= 0) {
			// request planet info at this point
			move_to_planet(planets[j]);
			solve_puzzles(puzzles[j]);
		}
		else {
			for (i = 0; i < 5; i++) {
				// at this point just find the first planet without a pending request for simplicity. 
				// can be later be optimized to find the closest planet without a pending request if we have time
				if (!pending_requests[i]) { 
					// request planet info
					move_to_planet(planets[i]);
					// request puzzle for planets[i]
				}
			}
		}
	}

	return 0;
}
